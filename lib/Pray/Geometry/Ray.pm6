class Pray::Geometry::Ray;

use Pray::Geometry::Vector3D;

has Pray::Geometry::Vector3D $.position;
has Pray::Geometry::Vector3D $.direction;

method normalize () {
	self.new(
		position => $.position,
		direction => $.direction.normalize
	)
}

#`[[[
method scale ($argument, :$center) {
	self.new(
		:position($center ??
			self.position.scale($argument, :$center)
		!!
			self.position.scale($argument)
		),
		:direction(self.direction.scale($argument))
	)
}

method rotate (*@arguments, :$center) {
	self.new(
		:position($center ??
			self.position.rotate(|@arguments, :$center)
		!!
			self.position.rotate(|@arguments)
		),
		:direction(self.direction.rotate(|@arguments))
	)
}
]]]

