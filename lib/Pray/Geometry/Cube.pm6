use v6;
use Pray::Geometry::Object;
class Pray::Geometry::Cube is Pray::Geometry::Object;

use Math::ThreeD::Vec3;
use Pray::Geometry::Ray;

method _contains_point (Vec3 $point) {
	for $point[0], $point[1], $point[2] {
		return False unless $_.abs < 1; 
	}

	return True;
}

method _ray_intersection (Pray::Geometry::Ray $ray) {
	my ($ray_pos, $ray_dir) = .position, .direction given $ray;

	my @axii = ^3;
	my @return;
	
	OUTER: for @axii -> $a {
		my $dir = $ray_dir[$a];
		next unless $dir;

		my $pos = $ray_pos[$a];

		my @u = (-1, 1).map: { ($_ - $pos) / $dir };
		my @p = @u.map: { $ray_pos.add( $ray_dir.mul($_) ).item };
		my @o_a = @axii.grep: {$_ != $a};

		for ^@p -> $i {
			my $p = @p[$i];
			
			next unless 
				$p[@o_a[0]].abs <= 1 &&
				$p[@o_a[1]].abs <= 1;
				
			my @norm = @axii.map: { $_ == $a ??
				$p[$_].sign
			!!
				0
			};
			
			@return.push([ $p.item, vec3(|@norm).item, @u[$i] ]);
			
			last OUTER if @return >= 2;
		}
	}
	
	return @return;
}


