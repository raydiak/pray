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

	my $count = $width * $height;

	my $s = Supply.for(^$count);

	my $complete = False;
	my $t = $s.tap:
		{
			my $point = hilbert_coord($width, $height, $_);
			my $color =
				$scene.screen_coord_color(|$point, $width, $height);
			$out.set(
				|$point,
				$color.r, $color.g, $color.b,
				:$preview
			);
		},
		done => {
			$complete = True;
			return;
		};

	until $complete {
		sleep 1;
	}
	
	# preview leaves cursor at end of last line to avoid scrolling the output
	$*ERR.say('') if $preview; 

	$*ERR.say("Writing to $out_file") unless :$quiet;
	$out.write_ppm($out_file);
}

#convert d to (x,y)
# seeking version to support fast near indexing without memory bloat
# caching the whole sequence was too slow and memory-intensive
sub hilbert_coord ($w, $h, $i) {
	# cache the mappings
	state %sizes;
	
	# key cache on rectangle dimensions
	my $size_key = "$w $h";

	my $size := %sizes{$size_key};

	unless $size {
		my $max = [max] $w, $h;
		my $dec_size = log($max) / log(2);
		my $hilbert_size = Int($dec_size);
		$hilbert_size++ if $hilbert_size < $dec_size;
		$hilbert_size = 2 ** $hilbert_size;
		$size<size> = $hilbert_size;
		$size<offset> = -1;
		$size<count> = $w * $h;
		$size<index> = -1;
	}
	
	my $coord;
	while ( my $dir = ($i <=> $size<index>) ) || !$coord {
		my $o = 0;
		while (
			(!$coord || $coord[0] >= $w || $coord[1] >= $h ) &&
			0 <= ($o += $dir) < $size<size> ** 2 - $size<offset>
		) {
			$coord = &hilbert_dist(
				$size<size>,
				$size<offset> + $o
			);
		}
		$size<offset> += $o if $o;
		$size<index> += $dir if $dir;
	}

	return $coord[0], $coord[1];
}

# copied and ported from wikipedia
# http://en.wikipedia.org/wiki/Hilbert_curve#Applications_and_mapping_algorithms
# assumes square of $n x $n size, $n = a power of two (2, 4, 8, 16, etc)
# $d is a 0-based integer index into the sequence ( 0 <= $d < $n ** 2 )
sub hilbert_dist ($n, $d) {
	my ($rx, $ry, $s, $t);
	$t = $d;
	my ($x, $y) = 0, 0;
	
	loop ($s=1; $s < $n; $s *= 2) {
		$rx = 1 +& ( $t / 2 );
		$ry = 1 +& ( $t +^ $rx );
		&hilbert_coord_rot($s, $x, $y, $rx, $ry);
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
		($x, $y) = $y, $x;
	}
	return;
}
