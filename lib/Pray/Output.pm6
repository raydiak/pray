class Pray::Output;

use Pray::Scene::Color;

has Int $.width;
has Int $.height;
has @!data = [Any xx $!width] xx $!height;

method set (Int $x, Int $y, $value) {
	@!data[$y][$x] = $value;
}

method color_ppm (Pray::Scene::Color $value) {
	sprintf(
		'%3d %3d %3d',
		$value.r*255,
		$value.g*255,
		$value.b*255
	)
}

method write_ppm ($filename) {
	my $fh = open($filename, :w);
	$fh.print("P3\n$!width $!height\n255");
	
	for 0..$!height-1 -> $y {
		my $line = "\n";
		
		for 0..$!width-1 -> $x {
			$line ~= ' ' if $x;
			$line ~= self.color_ppm( @!data[$y][$x] );
		}
		
		$fh.print($line);
	}
	
	$fh.close;
	return;
}


