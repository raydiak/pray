class Pray::Scene::Intersection;

use Pray::Geometry::Ray;
use Pray::Scene::Object;
use Math::ThreeD::Vec3;

# tested ray
has Pray::Geometry::Ray $.ray;

# collided object
has Pray::Scene::Object $.object;

# tested scene
has $.scene;

# collision position in scene space
has Vec3 $.position =
	$!ray && $!distance ??
		$!ray.position.add(
			$!ray.direction.mul($!distance)
		) !!
		Vec3;

# collision distance in ray lengths
has $.distance =
	$!ray && $!position ??
		sqrt(
			$!position.sub($!ray.position).length_sqr /
			$!ray.direction.length_sqr
		) !!
		Any;

# surface normal at intersection
has Vec3 $.direction;

# objects which contained the ray before collision
has @.containers =
	();

# whether we are hitting the inside or outside of the object
has Bool $.exiting =
	$!object ?? $!object ∈ @!containers !! False;


