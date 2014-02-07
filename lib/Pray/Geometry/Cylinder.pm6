use v6;
use Pray::Geometry::Object;
class Pray::Geometry::Cylinder is Pray::Geometry::Object;

use Math::ThreeD::Vec3;
use Pray::Geometry::Ray;

method _contains_point (Vec3 $point) {
	?( $point[2].abs < 1 && $point[0]**2+$point[1]**2 < 1 )
}

method _ray_intersection (
	Pray::Geometry::Ray $ray
) {
	my ($ray_pos, $ray_dir) = .position, .direction given $ray;

	# $ray_dir.length_sqr;
	my $a = $ray_dir[0]**2 + $ray_dir[1]**2;
	
	# $ray_dir.dot( $ray_pos ) * 2;
	my $b = ( $ray_pos[0]*$ray_dir[0] + $ray_pos[1]*$ray_dir[1] ) * 2;
	
	# $ray_pos.length_sqr - 1
	my $c = $ray_pos[0]**2 + $ray_pos[1]**2 - 1;
	
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
				my $z = @p[$i][2];
				if -1 <= $z <= 1 {
					@return_points.push([
						$_,
						vec3(.[0], .[1], 0).item,
						@u[$i]
					]) given @p[$i];
				} elsif
					@list > 1 && (
						-1 <= @p[1-$i][2] <= 1 ||
						$z.sign != @p[1-$i][2].sign
					)
				{
					my $sign = $z.sign;
					my $u = ($sign - $ray_pos[2]) / $ray_dir[2];
					my $point = $ray_pos.add( $ray_dir.mul($u));
					@return_points.push([
						$point,
						vec3(0, 0, $sign).item,
						$u
					]);
				}
			}
		} elsif $c <= 0 && $ray_dir[2] {
			@list = -1, 1;
			for @list -> $sign {
				my $u = ($sign - $ray_pos[2]) / $ray_dir[2];
				my $point = $ray_pos.add( $ray_dir.mul($u));
				@return_points.push([
					$point,
					vec3(0, 0, $sign).item,
					$u
				]);
			}
		}
	}
	
	return @return_points;
}


