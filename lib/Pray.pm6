module Pray;

use Pray::Scene;
use Pray::Scene::Color;
use Pray::Output::PPM;

# in the interest of simplicity, the rendering loop currently resides here with preview and file IO written into it directly - this is more or less the "front end" for the moment
# a more generic rendering loop should be implemented in Scene, and this should be refactored with appropriate separation of concerns and future concurrency in mind
# preview could be an output module
# scene param should accept a filename, a hash, or a scene instance object
# output param should be optional and we should return the results instead of writing to a file if output is not specified
# output could also be passed an array ref to be filled in with colors...or a routine to call for each pixel

our sub render (
	$scene_file,
	$out_file,
	Int $width is copy,
	Int $height is copy,
	Bool :$quiet = True,
	Bool :$verbose = False,
	Bool :$preview = !$quiet
) {
	if !$height {
		if $width {
			$height = $width;
		} else {
			die 'Width and/or height must be specified';
		}
	} elsif !$width {
		$width = $height;
	}
	
	my $scene = Pray::Scene.load($scene_file);
	my $ppm = Pray::Output::PPM.new($out_file, $width, $height);

	# terminal output stuff...should tuck this ugliness away in its own routines or something - and consider that this won't be easily adapted to concurrency
	my $v_cols = 0;
	my $v_fmt;
	if $verbose {
		$v_cols = "$height".chars;
		$v_fmt = '%' ~ $v_cols ~ 'd/%' ~ $v_cols ~ 'd';
		$v_fmt ~= ' ' if $preview;
		$v_cols = sprintf($v_fmt, $height, $height).chars;
	}
	my $preview_chars = 2;
	my $preview_reduce_x = my $preview_reduce_y = 1;
	my $p_cols;
	if $preview {
		my $p_cols_max = 78 - $v_cols;
		$p_cols = $width*2;

		while $p_cols > $p_cols_max {
			if $preview_chars == 2 {
				$preview_chars = 1;
				$preview_reduce_y = 2;
			} else {
				$preview_reduce_x += 1;
				$preview_reduce_y = $preview_reduce_x * 2;
			}
			$p_cols = ($width div $preview_reduce_x) * $preview_chars;
			$p_cols += $preview_chars if $width % $preview_reduce_x;
		}
		
		say($*ERR,
			(' ' x $v_cols) ~ 
			'┌' ~
			('─' x $p_cols) ~
			'┐'
		);
	}

	my $start_time = now;

	for ^$height -> $y {
		my $quiet_line = ?( $y % $preview_reduce_y );
		$*ERR.print(sprintf($v_fmt, $y+1, $height)) if $verbose && !$quiet_line;
		
		$*ERR.print('│') if $preview && !$quiet_line;
		
		for ^$width -> $x {
			my $color = $scene.camera.screen_coord_color(
				$x, $y,
				$width, $height,
				$scene
			).clip;

			$*ERR.print( preview_color($color, $preview_chars) )
				if $preview && !$quiet_line && !($x % $preview_reduce_x);

			$ppm.set_next($color);
		}

		$*ERR.print('│') if $preview && !$quiet_line;

		$*ERR.print("\n") if ($preview || $verbose) && !$quiet_line;
	}

	my $seconds = now - $start_time;
	
	say($*ERR,
		(' ' x $v_cols) ~ 
		'└' ~
		('─' x $p_cols) ~
		'┘'
	) if $preview;

	$ppm.write;

	unless $quiet {
		my $pixels = $width * $height;
		my $time = seconds_to_time($seconds);
		$*ERR.print( sprintf(
			"$pixels pixels / $time = %.2f pixels/sec\n",
			$pixels / $seconds
		) );
	}
}

sub seconds_to_time ($seconds is copy) {
	constant @time_units = (
		[	86400,	'day',			'dy'	],
		[	3600,	'hour',			'hr'	],
		[	60,		'minute',		'min'	],
		[	1,		'second',		'sec'	],
		[	1/1000,	'millisecond',	'ms'	]
	);

	my $return = '';
	for @time_units {
		my $last = ($_ === @time_units[*-1]);
		next unless $_[0] < $seconds || $last;
		my $value = $seconds / $_[0];
		$value = $last ?? +sprintf('%.2f', $value) !! $value.Int;
		next unless $value;
		$seconds -= $value * $_[0];
		my $plural = $value == 1 || $_[2] ~~ /'s' $/ ?? '' !! 's';
		$return ~= ' ' if $return.chars;
		$return ~= "$value $_[2]$plural";
	}

	return $return;
}

sub preview_color (Pray::Scene::Color $color, $count = 2) {
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


