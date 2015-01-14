class Pray::Geometry::Vector3D;

use Pray::Geometry::Matrix3D;

has $.x = 0;
has $.y = 0;
has $.z = 0;



our sub v3d ($x, $y, $z) is export {
    $?CLASS.new(x => $x, y => $y, z => $z)
}



method clone () {
    self.bless :$!x, :$!y, :$!z;
}



method length_sqr () {
    $!x*$!x + $!y*$!y + $!z*$!z
}



method length () {
    my $return = self.length_sqr;
    !$return || $return == 1 ?? $return !! sqrt $return;
    #self.length_sqr.sqrt
}



method normalize (Numeric $length = 1) {
    my $current_length_sqr = self.length_sqr;
    
    $current_length_sqr != 0 && $current_length_sqr != $length*$length ??
        self.scale( $length / sqrt($current_length_sqr) )
    !!
        self.clone
    ;
}



method add (Pray::Geometry::Vector3D $vector) {
    v3d(
        $.x + $vector.x,
        $.y + $vector.y,
        $.z + $vector.z
    )
}



method subtract (Pray::Geometry::Vector3D $vector) {
    v3d(
        $.x - $vector.x,
        $.y - $vector.y,
        $.z - $vector.z
    )
}



method dot (Pray::Geometry::Vector3D $vector) {
    $.x * $vector.x +
    $.y * $vector.y +
    $.z * $vector.z
}



method cross (Pray::Geometry::Vector3D $vector) {
    v3d(
        self.y * $vector.z - self.z * $vector.y,
        self.z * $vector.x - self.x * $vector.z,
        self.x * $vector.y - self.y * $vector.x
    )
}



method angle (Pray::Geometry::Vector3D $vector) {
    acos self.angle_cos($vector)
}



method angle_cos (Pray::Geometry::Vector3D $vector) {
    self.dot($vector) /
    ( self.length * $vector.length )
}



multi method scale (
    Numeric $scale,
    Pray::Geometry::Vector3D :$center
) {
    $center ??
        self.subtract($center).scale($scale).add($center)
    !! v3d(
        $.x * $scale,
        $.y * $scale,
        $.z * $scale
    )
}



multi method scale (
    Pray::Geometry::Vector3D $scale,
    Pray::Geometry::Vector3D :$center
) {
    $center ??
        self.subtract($center).scale($scale).add($center)
    !! v3d(
        $.x * $scale.x,
        $.y * $scale.y,
        $.z * $scale.z
    )
}



method reflect (Pray::Geometry::Vector3D $vector) {
    $vector.scale(
        2 * self.dot($vector)
    ).subtract(self)
}



method reverse () {
    v3d( -$!x, -$!y, -$!z )
}



multi method rotate (
    $axis where enum <x y z>,
    $angle,
    Pray::Geometry::Vector3D :$center
) {
    $center ??
        self.subtract($center).rotate($axis, $angle).add($center)
    !! {
        my ($sin, $cos) = sin($angle), cos($angle);
        my @axii = <x y z>.grep: {$_ ne $axis};
        my %result;
        %result{@axii[0]} = self."@axii[0]"() * $cos - self."@axii[1]"() * $sin;
        %result{@axii[1]} = self."@axii[0]"() * $sin + self."@axii[1]"() * $cos;
        %result{$axis} = self."$axis"();
        v3d(
            %result<x>,
            %result<y>,
            %result<z>
        );
    }();
}



multi method rotate (
    Pray::Geometry::Vector3D $axis,
    $angle,
    Pray::Geometry::Vector3D :$center
) {
    $center ??
        self.subtract($center).rotate($axis, $angle).add($center)
    !! {
        my $cos = cos $angle;
        self.scale($cos).add(
            $axis.cross(self).scale(sin $angle)
        ).add(
            $axis.scale( $axis.dot(self) * (1-$cos) )
        );
    }();
}



method transform (Pray::Geometry::Matrix3D $m) {
    my $v := $m.values;
    $?CLASS.new(
        x => $!x*$v[0][0] + $!y*$v[0][1] + $!z*$v[0][2] + $v[0][3],
        y => $!x*$v[1][0] + $!y*$v[1][1] + $!z*$v[1][2] + $v[1][3],
        z => $!x*$v[2][0] + $!y*$v[2][1] + $!z*$v[2][2] + $v[2][3]
    )
}



