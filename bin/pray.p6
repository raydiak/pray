#!/usr/bin/env perl6

use v6;

use lib $?FILE.IO.parent.parent.child('lib');

use Pray;

sub MAIN (
	Str $scene = 'scene.json',
	Str $image? is copy,
	Int :$width,
	Int :$height,
	Bool :$quiet = False,
	Bool :$verbose = False,
	Bool :$preview = !$quiet,
) {
	$image //= 
		$scene.IO.basename ~~ /^ (.*) \. .*? $/ ??
		"$0.ppm" !!
		'scene.ppm';
	
	Pray::render(
		$scene,
		$image,
		$width,
		$height,
		:$quiet,
		:$verbose,
		:$preview,
	);
}


