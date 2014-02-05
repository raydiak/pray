class Pray::Geometry::Ray;

use Math::ThreeD::Vec3;

has Vec3 $.position;
has Vec3 $.direction;

method normalize () {
	self.new(
		position => $.position,
		direction => $.direction.mul(1/$.direction.length);
	)
}
