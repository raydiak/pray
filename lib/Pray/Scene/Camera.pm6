use v6;

class Pray::Scene::Camera::Anaglyph {
	use Pray::Scene::Color;
	use Pray::Scene::Lighting;
	has Real $.separation = 1/6;
	has Pray::Scene::Lighting $.left = 
		Pray::Scene::Lighting.new(color => rgb 1,0,0);
	has Pray::Scene::Lighting $.right =
		Pray::Scene::Lighting.new(color => rgb 0,0,1);
};

class Pray::Scene::Camera {
	use Math::ThreeD::Vec3;
	use Pray::Scene::Color;

	has Vec3 $.position = vec3(3,-7,3);
	has Vec3 $.object = vec3(0,0,0);
	has Real $.roll = 0;
	has Real $.roll_radians = self.roll * pi / 180;

	has Real $.fov = 35;
	has Real $.fov_radians = self.fov * pi / 180;
	has Real $.plane_size =
		sin(self.fov_radians / 2) * 2 /
		cos(self.fov_radians / 2);

	has Real $.exposure = 1;

	has Pray::Scene::Camera::Anaglyph $.anaglyph;

	has $.vectors = self._build_vectors;

	has %!containers;

	method polar () {
		my ($x, $y, $z) = .[0], .[1], .[2] given $.object.sub($.position);
		my $theta = atan2($y, $x);
		my $phi = atan2($z, sqrt($x*$x + $y*$y));
		return $theta, $phi;
	}

	method _build_vectors () {
		my $quarter_circle = pi / 2;

		my ($theta, $phi) = self.polar;
		my $roll_radians = self.roll_radians;

		my $view_c = vec3(
			cos($theta) * cos($phi),
			sin($theta) * cos($phi),
			sin($phi)
		);

		my $view_u = vec3(
			cos($theta - $quarter_circle),
			sin($theta - $quarter_circle),
			0
		).rotate($view_c, $roll_radians);

		my $view_v = vec3(
			cos($theta) * cos($phi + $quarter_circle),
			sin($theta) * cos($phi + $quarter_circle),
			sin($phi + $quarter_circle)
		).rotate($view_c, $roll_radians);

		return $view_c, $view_u, $view_v;
	}

	method containers ($scene) {
		%!containers{$scene.WHICH} //=
			$scene.objects.grep({ .geometry.contains_point(self.position) }) //
			[]
	}

	method plane_coord_color (Real $x, Real $y, $scene, Real :$recurse = 16) {
		my $return = black;
		my @views;
		
		if $!anaglyph {
			@views = -1, 1;
			for @views {
				$_ = hash(
					pos => $!position.add( $!vectors[1].mul(
						$!anaglyph.separation / 2 * $_
					) ),
					color => $_ < 0 ?? $!anaglyph.left !! $!anaglyph.right,
				)
			};
		} else {
			@views[0] = hash(pos => $!position);
		}
		
		my $dir = $!vectors[0]\
			.add( $!vectors[1].mul($x) )\
			.plus( $!vectors[2].mul($y) )\
			.normalize;
		
		for @views {
			my $ray = Pray::Geometry::Ray.new(
				position => $_<pos>,
				direction => $dir
			);

			my $add = $scene.ray_color(
				$ray,
				:$recurse,
				:containers(self.containers($scene))
			);

			$add = $_<color>.color_scaled.scale($add.brightness) if $_<color>;

			$return .= add($add);
		}

		$return .= scale($!exposure);

		return $return;
	}

	method screen_coord_color (
		Real $x, Real $y,
		Real $w, Real $h,
		$scene,
		Real :$recurse = 16,
	) {
		self.plane_coord_color(
			($x - ($w-1)/2) * $_,
			(($h-1)/2 - $y) * $_,
			$scene,
			:$recurse
		) given $.plane_size / [min] $w, $h
	}

}

