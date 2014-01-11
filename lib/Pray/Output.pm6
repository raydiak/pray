use v6;

use Pray::Scene::Color;

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

sub color_ppm (Pray::Scene::Color $value) {
	sprintf(
		'%3d %3d %3d',
		$value.r*255,
		$value.g*255,
		$value.b*255
	)
}

sub color_preview (Pray::Scene::Color $color, $count = 1) {
	return '*' x $count unless $color;
	constant @chars = ' ', < ░ ▒ ▓ █ >;
	constant $shades = @chars - 1;
	my $shade = ( ($color.r + $color.g + $color.b) / 3 );
	my $return = '';

	for ^$count {
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
		$return ~= $char;
	}
	
	return $return;
}

class Pray::Output::Color {
	has $.value;
	
	has $.ppm =
		$!value.defined ??
		color_ppm($!value) !!
		'';
	
	has $.preview = color_preview($!value);
}

class Pray::Output {
	has Int $.width;
	has Int $.height;
	
	# this could be what is adding all the new startup time
		# make preview method check for undefinedness and remove this
	has @!data = [] xx $!height;
	
	has Int $!incomplete = $!width * $!height;

	method set (Int $x, Int $y, $value, Bool :$preview = True) {
		if self.get($x, $y) {
			$!incomplete++ unless $value;
		} else {
			$!incomplete-- if $value;
		}
		@!data[$y][$x] = Pray::Output::Color.new(:$value);
		self.progress( :$preview, :force(!$!incomplete) ) if $preview;
		return;
	}

	method get (Int $x, Int $y) {
		my $data = @!data[$y][$x];
		
		return $data.value if $data.defined;

		return;
	}

	method get_preview (Int $x, Int $y) {
		my $data = @!data[$y][$x];
		
		return $data.preview if $data.defined;

		return '*';
	}

	method get_ppm (Int $x, Int $y) {
		@!data[$y][$x].ppm
	}

	method write_ppm ($filename) {
		my $fh = open($filename, :w);
		$fh.print("P3\n$!width $!height\n255");
		
		for 0..$!height-1 -> $y {
			my $line = "\n";
			
			for 0..$!width-1 -> $x {
				$line ~= ' ' if $x;
				$line ~= self.get_ppm($x, $y);
			}
			
			$fh.print($line);
		}
		
		$fh.close;
		return;
	}

	# this is still very messy, but at least the mess is more encapsulated now
	method progress (
		Bool :$preview = True,
		Bool :$force = False,
	) {
		# did I mention very messy?
		# these things should be moved into a sane set of private properties
		state $preview_chars = 2;
		state $preview_reduce_x = 1;
		state $preview_reduce_y = 1;
		state $p_cols_max = 78;
		state $p_cols = 0;
		state $total = $!width * $!height;

		if $p_cols == 0 {
			$p_cols = $!width * 2;
			while $p_cols > $p_cols_max {
				if $preview_chars == 2 {
					$preview_chars = 1;
					$preview_reduce_y = 2;
				} else {
					$preview_reduce_x = $preview_reduce_x + 1;
					$preview_reduce_y = $preview_reduce_x * 2;
				}
				$p_cols = ($!width div $preview_reduce_x) * $preview_chars;
				$p_cols = $p_cols + $preview_chars
					if $!width % $preview_reduce_x;
			}
		}
		
		my $this_time = now;
		state $first_time = $this_time;
		state $last_time;
		state $delay = 2;
		
		return if !$force && $last_time && ($this_time - $last_time < $delay);
		$last_time = $this_time;
		
		my $complete = $total - $!incomplete;
		my $total_time = $this_time - $first_time;

		my $out ~= '┌' ~ '─' x $p_cols ~ "┐\n";

		my int $width = $!width;
		my int $height = $!height;
		my @data := @!data;
		my int $x = 0;
		my int $y = 0;
		loop ($y = 0; $y < $height; $y = $y + 1) {
			next if $y % $preview_reduce_y;
			
			$out ~= '│';
			
			loop ($x = 0; $x < $width; $x = $x + 1) {
				next if $x % $preview_reduce_x;
				if @data[$y][$x] -> $_ {
					$out ~= .preview x $preview_chars;
				} else {
					$out ~= '*' x $preview_chars;
				}
			}

			$out ~= "│\n";
		}

		$out ~= '└' ~ '─' x $p_cols ~ "┘\n";

		if $!incomplete != 0 {
			$out ~= sprintf('%3d%%', $complete * 100 / $total);

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

		my $run_time = now - $this_time;
		$delay = $run_time * 10;
		$delay = 1 if $delay < 1;
		$delay = 60 if $delay > 60;

		$*ERR.print( sprintf(' (%ds)', $delay) )
			unless $!incomplete == 0;

		return;
	}
}

