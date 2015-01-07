class Pray::Output::PPM;

use Pray::Scene::Color;

has Str $.filename;
has Int $.width;
has Int $.height;
has IO::Handle $.filehandle;

method new ($filename, $width, $height) {
    my $fh = open($filename, :w);
    my $self = self.bless(
        filename => $filename,
        filehandle => $fh,
        width => $width,
        height => $height
    );
    $fh.print("P3\n$width $height\n255\n");
    return $self;
}

method set_next (Pray::Scene::Color $color) {
    my $color_str = sprintf(
        '%3d %3d %3d ',
        $color.r*255,
        $color.g*255,
        $color.b*255
    );
    $.filehandle.print($color_str);
    return;
}

method write () {
    $.filehandle.close();
    return;
}


