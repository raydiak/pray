class Pray::Output;

subset PInt of Int where * > 0;

has Str $.file;
has PInt $.width;
has PInt $.height;

has PInt $.length = $!width * $!height;
has Buf[uint8] $.buffer = Buf[uint8].new(0 xx $!length * 3);
has PInt $.preview_reduce = ($!width div 80) + ($!width mod 80 > 0);
has PInt $.preview_width = preview_scale($!width, $!preview_reduce);
has PInt $.preview_height = preview_scale($!height, $!preview_reduce * 2);
has Str $.preview = (' ' x $!preview_width xx $!preview_height).join: "\n";
has @.dirty;
has $.channel = Channel.new;
has $.promise;
method !promise () is rw { $!promise };

method new (|) {
    my $self = callsame;

    $self!promise = start {
        my $channel = $self.channel;
        my $closed = $channel.closed;
        until $closed {
            while my @in = $channel.poll {
                $self!set(|@in);
            }
            $self.preview;
            sleep .25;
        }
    };

    $self;
}

sub preview_scale ($v, $reduction) {
    ($v div $reduction) + !($v %% $reduction);
}

method coord_index ($x, $y) { ($y * $!width + $x) * 3 }

method coord_preview ($x, $y) {
    preview_scale($x, $!preview_reduce),
    preview_scale($y, $!preview_reduce * 2);
}

method coord_preview_index ($x is copy, $y is copy) {
    ($x, $y) = self.coord_preview($x, $y);
    self.preview_coord_index: $x, $y;
}

method preview_coord_index ($x, $y) {
    $y * ($!width + 1) + $x;
}

method write () {
    $!channel.close;
    $!promise.result;

    my $fh = $!file.IO.open: :w;
    $fh.print: "P3\n$!width $!height\n255\n";
    #$fh.print: $!buffer[$_] ~ ' ' for ^($!length * 3);
    my $len = $!width * 3;
    for ^$!height -> $row {
        my $i = $row * $len;
        my $line = '';
        $line ~= "\n" if $row;
        $line ~= $!buffer[$_] ~ ' ' for $i .. $i + $len - 1;
        $fh.print: $line;
    }
    $fh.close;
}

sub process ($_) {
    $_ <= 0 ?? 0 !!
    $_ >= 1 ?? 255 !!
    ($_ * 256).Int;
}

method set ($x, $y, $r, $g, $b) {
    $!channel.send: [$x, $y, $r, $g, $b];
}

method !set ($x, $y, $r, $g, $b) {
    my $i = self.coord_index($x, $y);

    $!buffer[$i++] = process $r;
    $!buffer[$i++] = process $g;
    $!buffer[$i]   = process $b;

    @!dirty.push: $x, $y;

    True;
}

method get ($x, $y) {
    my $i = self.coord_index($x, $y);
    $!buffer[$i++]/255, $!buffer[$i++]/255, $!buffer[$i]/255;
}

method preview () {
    while @!dirty {
        my ($x, $y) = @!dirty.splice(0, 2);

        next unless
            $x %% $!preview_reduce &&
            $y %% ($!preview_reduce * 2);

        my $i = self.coord_preview_index($x, $y);

        $!preview.substr-rw($i, 1) = preview_char |@( self.get($x, $y) );
    }
    
    state &clear = $*DISTRO.is-win ?? {run 'cls'} !! {run 'clear'};
    clear;
    print $!preview;
}

sub preview_char ($r, $g, $b) {
    constant @chars = ' ', '░', '▒', '▓', '█';
    constant $shades = @chars - 1;
    my $shade = ($r + $g + $b) / 3;

    my $char;
    given $shade {
        when $_ >= 1 { $char = @chars[*-1] }
        when $_ <= 0 { $char = @chars[0] }
        default {
            my $i = $shade * $shades;
            $i += rand - .5; # dithering
            $i .= Int;
            $i = [max] 1, [min] $shades, $i+1;
            $char = @chars[$i];
        }
    }
    
    $char;
}


