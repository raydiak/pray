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

	for ^$height -> $y {
		for ^$width -> $x {
			my $color = $scene.camera.screen_coord_color(
				$x, $y,
				$width, $height,
				$scene
			).clip;

			$out.set($x, $y, $color, :$preview);
		}
	}

	$out.write_ppm($out_file);

	print "\n" if $preview;
}

