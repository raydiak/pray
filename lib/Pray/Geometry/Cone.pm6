use v6;
use Pray::Geometry::Object;
class Pray::Geometry::Cone is Pray::Geometry::Object;

use Math::ThreeD::Vec3;
use Pray::Geometry::Ray;

method _contains_point (Vec3 $point) {
	$point[2].abs < 1 &&
	$point[0]**2 + $point[1]**2 < ( .5 - $point[2] / 2 )**2
}

method _ray_intersection (
	Pray::Geometry::Ray $ray
) {
	my ($ray_pos, $ray_dir) = .position, .direction given $ray;
	my $ray_pos_z = ($ray_pos[2] - 1) / 2;
	my $ray_dir_z = $ray_dir[2] / 2;

	my $a =
		$ray_dir[0]**2 +
		$ray_dir[1]**2 -
		$ray_dir_z**2;
	
	my $b = (
		$ray_pos[0] * $ray_dir[0] +
		$ray_pos[1] * $ray_dir[1] -
		$ray_pos_z * $ray_dir_z
	) * 2;
	
	my $c = $ray_pos[0]**2 + $ray_pos[1]**2 - $ray_pos_z**2;
	
	my $determinant = $b * $b - 4 * $a * $c;
	
	my @return_points;

	if ($determinant >= 0) {
		my $det_root = 0;
		my @list;
		if $determinant > 0 {
			$det_root = sqrt $determinant;
			@list = -1, 1;
		} elsif $a {
			@list = 0;
		}

		if @list {
			my @u = @list.map: { (-$b + $det_root*$_) / (2 * $a) };
			my @p = @u.map: { $ray_pos.add( $ray_dir.mul($_) ).item };
			for ^@list -> $i {
				if -1 <= @p[$i][2] <= 1 {
					@return_points.push([
						$_,
						vec3(.[0], .[1], 0)\
							.normalize\
							.plus( vec3(0, 0, .5) )\
							.times( 1 / sqrt(1.25) ).item, # norm w/known length
						@u[$i]
					]) given @p[$i];
				} elsif @list > 1 && (-1 <= @p[1-$i][2] <= 1) {
					my $u = (-1 - $ray_pos[2]) / $ray_dir[2];
					my $point = $ray_pos.add( $ray_dir.mul($u) );
					@return_points.push([
						$point,
						vec3(0, 0, -1).item,
						$u
					]);
				}
			}
		}
	}
	
	return @return_points;
}


