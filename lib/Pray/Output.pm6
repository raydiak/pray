use v6;

sub seconds_to_time ($seconds is copy, int :$parts is copy = 2) {
	constant @time_units = (
		[	86400,	'day',			'dy'	],
		[	3600,	'hour',			'hr'	],
		[	60,		'minute',		'min'	],
		[	1,		'second',		'sec'	],
		#[	1/1000,	'millisecond',	'ms'	]
	);

	return '0 secs' unless $seconds;

	my $return = '';
	for @time_units {
		my $last = ($_ === @time_units[*-1]);
		next unless $_[0] < $seconds || $last;
		
		my $value = $seconds / $_[0];
		$last ||= $parts > 1;
		$value = $last ?? +sprintf('%d', $value) !! $value.Int;
		next unless $value;
		
		$seconds -= $value * $_[0];
		my $plural = $value == 1 || $_[2] ~~ /'s' $/ ?? '' !! 's';
		
		$return ~= ' ' if $return.chars;
		$return ~= "$value $_[2]$plural";
		
		$parts = $parts - 1;
		last if $parts == 0;
	}

	return $return;
}

sub color_ppm ($r, $g, $b) {
	$r.defined && $g.defined && $b.defined ?? 
		sprintf(
			'%3d %3d %3d',
			$r*255,
			$g*255,
			$b*255
		) !!
		'  0   0   0'
}

sub color_preview ($r, $g, $b) {
	return '*' unless $r.defined && $g.defined && $b.defined;
	constant @chars = ' ', < ░ ▒ ▓ █ >;
	constant $shades = @chars - 1;
	my $shade = ( ($r + $g + $b) / 3 );

	my $char;
	given $shade {
		when $_ >= 1 { $char = @chars[*-1] }
		when $_ <= 0 { $char = @chars[0] }
		default {
			my $i = $shade * $shades;
			$i += rand - .5; # dithering
			$i .= Int;
			$i = [max] 1, [min] $shades, $i+1;
			$char = @chars[$i];
		}
	}
	
	return $char;
}

class Pray::Output {
	has Int $.width;
	has Int $.height;
	has Int $!pixels = $!width * $!height;

	my $val_undef = '*' x 16 ~ "\n";
	sub val_fmt ($v?) { $v.defined ?? sprintf("% 16.12g\n", $v) !! $val_undef }
	
	sub _build_values (Int $w, Int $h) {
		my $val = val_fmt();
		my $return = [$val x $w * 3 xx $h];
		return $return;
	}
	
	has $!values = _build_values($!width, $!height);
	
	has Int $!val_len = val_fmt().chars;
	has Int $!pix_len = 3 * $!val_len;
	
	has Int $.incomplete is rw = $!pixels;

	has Int $.preview_width = [min] $!width, 80;
	has Real $!preview_reduce = $!width / $!preview_width;
	has Int $.preview_height = Int($!height / $!preview_reduce / 2);
	has Str $.preview is rw = (
		('*' x $!preview_width)
		xx $!preview_height
	).join("\n");

	method preview_coord ($x, $y) {
		Int($x / $!preview_reduce),
		Int($y / $!preview_reduce / 2)
	}
	
	method preview_index ($x is copy, $y is copy) {
		my ($x_c, $y_c) = self.preview_coord($x, $y);
		return $y_c * ($!preview_width+1) + $x_c;
	}

	method update_preview ($x, $y, :@color is copy) {
		# this was pretty, but too slow, especially all the get()s
		unless @color {
			my @preview_coord = self.preview_coord($x, $y);
			
			my $x_start = @preview_coord[0] * $!preview_reduce;
			my $x_stop = [min] $!width - 1, $x_start + $!preview_reduce;
			
			my $x_start_c = $x_start.Int;
			my $x_stop_c = $x_stop.Int;
			$x_stop_c++ if $x_stop_c != $x_stop && $x_stop_c + 1 <= $!height - 1;
			
			my $x_start_shade = 1 - ($x_start - $x_start_c) / $!preview_reduce;
			my $x_stop_shade = 1 - ($x_stop_c - $x_stop) / $!preview_reduce;

			my $y_start = @preview_coord[1] * $!preview_reduce * 2;
			my $y_stop = [min] $!height - 1, $y_start + $!preview_reduce * 2;

			my $y_start_c = $y_start.Int;
			my $y_stop_c = $y_stop.Int;
			$y_stop_c++ if $y_stop_c != $y_stop && $y_stop_c + 1 <= $!height - 1;
			
			my $y_start_shade = 1 - ($y_start - $y_start_c) / $!preview_reduce / 2;
			my $y_stop_shade = 1 - ($y_stop_c - $y_stop) / $!preview_reduce / 2;
			
			my $colors = 0;
			for $y_start_c..$y_stop_c -> $y_c {
				for $x_start_c..$x_stop_c -> $x_c {
					my ($r, $g, $b) = self.get($x_c, $y_c);
					next unless $r.defined && $g.defined && $b.defined;
					#return unless $r.defined && $g.defined && $b.defined;
					my $s = 1;
					$s *= $x_start_shade if $x_c == $x_start_c;
					$s *= $x_stop_shade if $x_c == $x_stop_c;
					$s *= $y_start_shade if $y_c == $y_start_c;
					$s *= $y_stop_shade if $y_c == $y_stop_c;
					$_ *= $s for $r, $g, $b;
					if @color {
						@color =
							@color[0] + $r,
							@color[1] + $g,
							@color[2] + $b;
					} else {
						@color = $r, $g, $b;
					}
					$colors += $s;
				}
			}
			if $colors && $colors != 1 {
				$_ /= $colors for @color;
			}
		}

		my $char = @color ?? color_preview(|@color) !! '*';
		my $i = self.preview_index($x, $y);
		substr-rw($!preview, $i, 1) = $char;
		return;
	}

	method set (
		Int $x, Int $y,
		Real $r, Real $g, Real $b,
		Bool :$preview = False,
	) {
		my ($r_v, $g_v, $b_v) = self.get($x, $y);
		
		# how to make this fast...???...
			# the answer was to split the huge string up
			# into an array of smaller strings
		substr-rw($!values[$y], $x*$!pix_len, $!pix_len) =
			($r, $g, $b)».map({ val_fmt $_ }).join('');
		
		if $preview {
			self.update_preview($x, $y, :color($r, $g, $b));
			self.progress( :$preview, :force(!$!incomplete) );
		}
		
		# this is last to make it useful for concurrency control:
			# Thread.yield while $out.incomplete
		$!incomplete-- unless $r_v.defined || $g_v.defined || $b_v.defined;

		return;
	}
	
	method get (Int $x, Int $y) {
		my @color;

		for 0..2 {
			my $val = substr(
				$!values[$y],
				$x * $!pix_len + $_ * $!val_len, $!val_len
			);
			
			if $val eq $val_undef {
				$val = Real;
			} else {
				$val = +$val;
			}
			push @color, $val;
		}
		
		return |@color;
	}

	method ppm_value (Int $x, Int $y) {
		my ($r, $g, $b) = self.get($x, $y);

		return color_ppm($r, $g, $b);
	}

	method write_ppm ($filename) {
		my $fh = open($filename, :w);
		$fh.print("P3\n$!width $!height\n255");
		
		for 0..$!height-1 -> $y {
			my $line = "\n";
			
			for 0..$!width-1 -> $x {
				$line ~= ' ' if $x;
				$line ~= self.ppm_value($x, $y);
			}
			
			$fh.print($line);
		}
		
		$fh.close;
		return;
	}

	method progress (
		Bool :$preview = True,
		Bool :$force = False,
	) {
		my $this_time = now;
		state $first_time;
		if !$first_time.defined {
			$first_time = 0;
		} elsif !$first_time {
			$first_time = $this_time;
		}
		state $last_time;
		my $delay = 1;
		
		return if !$force && $last_time && ($this_time - $last_time < $delay);
		$last_time = $this_time;
		
		my $complete = $!pixels - $!incomplete;
		my $total_time = $this_time - $first_time;

		my $out = $!preview;

		$out ~= "\n" if $!incomplete || $total_time;

		if $!incomplete {
			$out ~= sprintf('%3d%%', $complete * 100 / $!pixels);

			$out ~= ' | ETA + ' ~
				seconds_to_time($!incomplete / $complete * $total_time)
				if $complete > 1 && $!incomplete != 0;

			$out ~= ' | ' if $total_time;
		}

		$out ~= sprintf(
			"$complete px / {seconds_to_time($total_time)} = %.2f px/s",
			$complete / $total_time
		) if $total_time;
		
		shell 'clear';
		$*ERR.print($out);

		return;
	}
}

