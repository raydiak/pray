module Pray;

use Pray::Scene;
use Pray::Scene::Color;
use Pray::Output;

# in the interest of simplicity, the rendering loop currently resides here with preview and file IO written into it directly - this is more or less the "front end" for the moment
# a more generic rendering loop should be implemented in Scene, and this should be refactored with appropriate separation of concerns and future concurrency in mind
# scene param should accept a filename, a hash, or a scene instance object
# output param should be optional and we should return the results instead of writing to a file if output is not specified
# output could also be passed an array ref to be filled in with colors...or a routine to call for each pixel

our sub render (
	$scene_file,
	$out_file,
	Int $width is copy,
	Int $height is copy,
	Bool :$quiet = True,
	#Bool :$verbose = False,
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
	my $out = Pray::Output.new(:$width, :$height);

	my $start_time = now;

	my @points = ( ^($width * $height) ).map: {
		hilbert_coord($width, $height, $_)
	};

	for @points -> @p {
		$out.set(
			|@p,
			$scene.screen_coord_color(|@p, $width, $height),
			:$preview
		);
	}

	$out.write_ppm($out_file);

	$*ERR.print("\n") if $preview;
}

#convert d to (x,y)
multi sub hilbert_coord ($w, $h, $d) {
	# cache the mappings
	state %sizes;
	
	# key cache on rectangle dimensions
	my $size_key = "$w $h";

	# build mapping as hilbert size and sequence offsets and add to cache
	unless %sizes{$size_key} {
		my $max = [max] $w, $h;
		my $size = log($max) / log(2);
		my $hilbert_size = Int($size);
		$hilbert_size++ if $hilbert_size < $size;
		$hilbert_size = 2 ** $hilbert_size;
		
		%sizes{$size_key}<hilbert_size> = $hilbert_size;
		
		my @offsets;
		my $offset = 0;
		for ^($w * $h) -> $i {
			my $coord;
			my $gap = -1;
			until ($coord && $coord[0] < $w && $coord[1] < $h) {
				$coord = hilbert_coord(
					$hilbert_size,
					$i + $offset + (++$gap)
				);
			}
			if $gap {
				$offset += $gap;
				@offsets.push: [$i, $offset];
			}
		}
		
		%sizes{$size_key}<offsets> = @offsets;
	}
	#die %sizes{$size_key}.perl;
	
	# find in-bounds index
	my $i = $d;
	for %sizes{$size_key}<offsets>[] -> $g {
		last if $d < $g[0];
		$i = $d + $g[1];
	}

	# get and return the coordinate
	return hilbert_coord(%sizes{$size_key}<hilbert_size>, $i);
}

# copied and ported from wikipedia
# http://en.wikipedia.org/wiki/Hilbert_curve#Applications_and_mapping_algorithms
# assumes square of $n x $n size, $n = a power of two (2, 4, 8, 16, etc)
# $d is a 0-based integer index into the sequence ( 0 <= $d < $n ** 2 )
multi sub hilbert_coord ($n, $d) {
	my ($rx, $ry, $s, $t);
	$t = $d;
	my ($x, $y) = 0, 0;
	
	loop ($s=1; $s < $n; $s *= 2) {
		$rx = 1 +& ( $t / 2 );
		$ry = 1 +& ( $t +^ $rx );
		hilbert_coord_rot($s, $x, $y, $rx, $ry);
		$x += $s * $rx;
		$y += $s * $ry;
		$t /= 4;
	}
	return [$x, $y];
}
 
# from same source as above
# rotate/flip a quadrant appropriately
sub hilbert_coord_rot ($n, $x is rw, $y is rw, $rx, $ry) {
	if ($ry == 0) {
		if ($rx == 1) {
			$x = $n-1 - $x;
			$y = $n-1 - $y;
		}
 
		#Swap x and y
		my $t = $x;
		$x = $y;
		$y = $t;
	}
}
