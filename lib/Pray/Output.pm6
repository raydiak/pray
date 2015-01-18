class Pray::Output;

subset PInt of Int where * > 0;
subset NNInt of Int where * >= 0;

has Str $.file;
has PInt $.width;
has PInt $.height;
has Bool $.quiet = False;
has Bool $.preview = !$!quiet;
has Bool $.sync = False;
has $.preview-pause = .5;
has $.preview-width = 80;
has $.preview-dither = 1/3;

has Buf[uint8] $!buffer = Buf[uint8].new(0 xx $!width * $!height * 3);
has PInt $!preview-scale-w = preview_scale($!width, $!preview-width - 2);
has PInt $!preview-scale-h = $!preview-scale-w * 2;
has PInt $!preview-w = preview_scale($!width, $!preview-scale-w);
has PInt $!preview-h = preview_scale($!height, $!preview-scale-h);
has Str $!preview-buffer =
    "┌{'─' x $!preview-w}┐\n" ~
    "│{'.' x $!preview-w}│\n" x $!preview-h ~
    "└{'─' x $!preview-w}┘";
has @!dirty;
has $!channel = $!sync ?? Any !! Channel.new;
has $!promise;
has $!next-preview = 0;
has $!begin-time;
has $.count = 0;
has $.finished = False;

method new (|) {
    callsame!init;
}

method !init () {

    # this workaround prevents substr-rw from causing string corruption later
    # TODO reduce & report
    # perl6 -MPray::Output -e 'my $o = Pray::Output.new(:width(64), :height(64)); sleep 2; $o.set(56, 56, 1, 1, 1); $o.finish;'
    substr-rw($!preview-buffer, $!preview-w+4, 0) = '';

    if $!sync {
        self.preview if $!preview;
    } else {
        $!promise = start {
            my $closed = $!channel.closed;

            if $!preview {
                until $closed {
                    while my @in = $!channel.poll {
                        self!set(|@in);
                    }
                    my $now = now;
                    sleep $!next-preview - $now if $!next-preview > $now;
                    self.preview;
                }
            } else {
                until $closed {
                    try { self!set: $!channel.receive }
                }
            }

            True;
        };
    }

    self;
}

sub preview_scale ($v, $reduction) {
    ($v div $reduction) + !($v %% $reduction);
}

method coord_index ($x, $y) { ($y * $!width + $x) * 3 }

method coord_preview ($x, $y) {
    preview_scale($x, $!preview-scale-w),
    preview_scale($y, $!preview-scale-h);
}

method coord_preview_index ($x is copy, $y is copy) {
    ($x, $y) = self.coord_preview($x, $y);
    self.preview_coord_index: $x, $y;
}

method preview_coord_index ($x, $y) {
    ($y + 1) * ($!preview-w + 3) + $x + 1;
}

method finish () {
    return True if $!finished;

    my $seconds = now - $!begin-time;

    unless $!sync {
        $!channel.close;
        $!promise.result;
    }

    if $!preview {
        self.preview;
        print "\n";
    }

    unless $!quiet {
        my $time = seconds_to_time($seconds);
        printf "$!count pixels / $time = %.2f pixels/sec\n",
            $!count / $seconds;
    }

    $!finished = True;

    True;
}

method write () {
    self.finish;

    my $fh = $!file.IO.open: :w;
    $fh.print: "P3\n$!width $!height\n255\n";
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
    ($_ * 255).Int;
}

method set (NNInt $x, NNInt $y, $r, $g, $b) {
    $!begin-time //= now;

    die "($x, $y) is outside of (0..{$!width-1}, 0..{$!height-1})"
        unless 0 <= $x < $!width && 0 <= $y < $!height;

    if $!sync {
        self!set($x, $y, $r, $g, $b)
    } else {
        $!channel.send: [$x, $y, $r, $g, $b];
    }

    $!count++;

    True;
}

method !set ($x, $y, $r, $g, $b) {
    my $i = self.coord_index($x, $y);

    $!buffer[$i]   = process $r;
    $!buffer[$i+1] = process $g;
    $!buffer[$i+2] = process $b;

    if $!preview {
        @!dirty.push: $x, $y;
        self.preview if $!sync && $!next-preview <= now;
    }

    True;
}

method !get ($x, $y) {
    my $i = self.coord_index($x, $y);
    $!buffer[$i], $!buffer[$i+1], $!buffer[$i+2];
}

method get ($x, $y) {
    self!get($x, $y).map: */255;
}

method preview () {
    if @!dirty {
        my @dirty = @!dirty.map({
            [[$^x, $^y], self.coord_preview($x,$y).item]
                if $x %% $!preview-scale-w && $y %% $!preview-scale-h;
        }).unique: :with(&infix:<eqv>), :as(*.[1]);

        for @dirty -> [$coord, $preview_coord] {
            substr-rw(
                $!preview-buffer,
                self.preview_coord_index(|$preview_coord), 1) =
                self.preview_char(|@( self!get(|$coord) )
            );
        }

        @!dirty = ();
    }
    
    state &clear = $*DISTRO.is-win ?? {shell 'cls'} !! {run 'clear'};
    clear;
    print $!preview-buffer;

    $!next-preview = now + $!preview-pause;

    True;
}

method preview_char ($r, $g, $b) {
    constant @chars = ' ', '░', '▒', '▓', '█';
    constant $shades = @chars - 1;
    my $shade = ($r + $g + $b) / 765;

    my $char;
    given $shade {
        when $_ >= 1 { $char = @chars[*-1] }
        when $_ <= 0 { $char = @chars[0] }
        default {
            my $i = $shade * $shades;
            $i += (rand - .5) * $!preview-dither if $!preview-dither;
            $i .= Int;
            $i = [max] 1, [min] $shades, $i+1;
            $char = @chars[$i];
        }
    }
    
    $char;
}

sub seconds_to_time ($seconds is copy) {
    constant @time_units = (
        [    86400,    'day',            'dy'    ],
        [    3600,    'hour',            'hr'    ],
        [    60,        'minute',        'min'    ],
        [    1,        'second',        'sec'    ],
        [    1/1000,    'millisecond',    'ms'    ]
    );

    my $return = '';
    for @time_units {
        my $last = ($_ === @time_units[*-1]);
        next unless $_[0] < $seconds || $last;
        my $value = $seconds / $_[0];
        $value = $last ?? +sprintf('%.2f', $value) !! $value.Int;
        next unless $value;
        $seconds -= $value * $_[0];
        my $plural = $value == 1 || $_[2] ~~ /'s' $/ ?? '' !! 's';
        $return ~= ' ' if $return.chars;
        $return ~= "$value $_[2]$plural";
    }

    return $return;
}


