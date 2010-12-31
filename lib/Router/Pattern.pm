package Router::Pattern;
use Boose;

has 'pattern';
has 'defaults'    => sub { {} };
has 'constraints' => sub { {} };
has 'method';
has 'name';
has 'prefix';

use Router::Match;

require Carp;

my $TOKEN = '[^\/()]+';

sub compile {
    my $self = shift;

    my $pattern = $self->pattern;
    return if ref $pattern eq 'Regexp';

    $self->{captures} = [];

    my $re = '';

    $pattern = '/' . $pattern unless $pattern =~ m{\A/};

    my $prefix = $self->prefix;
    if (defined $prefix) {
        $pattern = "/$prefix$pattern";
    }

    my $par_depth = 0;

    pos $pattern = 0;
    while (pos $pattern < length $pattern) {
        if ($pattern =~ m{ \G /:($TOKEN) }gcxms) {
            $re .= '/';

            my $name = $1;
            if (exists $self->constraints->{$name}) {
                my $constraint = $self->constraints->{$name};
                $re .= "($constraint)";
            }
            else {
                $re .= '([^\/]+)';
            }

            push @{$self->{captures}}, $name;
        }
        elsif ($pattern =~ m{ \G /\*($TOKEN) }gcxms) {
            $re .= '/';

            my $name = $1;

            $re .= '(.*)';

            push @{$self->{captures}}, $name;
        }
        elsif ($pattern =~ m{ \G /($TOKEN) }gcxms) {
            $re .= '/';

            my $text = $1;
            $re .= quotemeta $text;
        }
        elsif ($pattern =~ m{ \G \( }gcxms) {
            $par_depth++;
            $re .= '(?: ';
        }
        elsif ($pattern =~ m{ \G \) }gcxms) {
            $par_depth--;
            $re .= ' )?';
        }
        else {
            my $sym = substr($pattern, pos($pattern), 1);

            $re .= $sym eq '/' ? $sym : quotemeta($sym);

            pos($pattern)++;
        }
    }

    if ($par_depth != 0) {
        Carp::croak("Parenthenes are not balanced in pattern '$pattern'");
    }

    try {
        $re = qr/\A $re \z/xmsi;
    }
    catch {
        Carp::croak("Can't compile pattern: '$pattern'");
    };

    $self->set_pattern($re);

    return $self;
}

sub match {
    my $self = shift;
    my $path = shift;
    my %args = @_;

    return unless $self->_match_method($args{method});

    $self->compile;

    $path = "/$path" unless $path =~ m{ \A / }xms;

    my $pattern = $self->pattern;

    my @captures = ($path =~ m/$pattern/);
    return unless @captures;

    my $params = {};
    if (!ref $self->defaults) {
        @$params{qw/controller action/} = split '#' => $self->defaults;
    }
    else {
        $params = $self->defaults;
    }

    my $prefix = $self->prefix;
    if (defined $prefix) {
        $params->{controller} = "$prefix-$params->{controller}";
    }

    foreach my $capture (@{$self->{captures}}) {
        last unless @captures;
        $params->{$capture} = shift @captures;
    }

    return $self->_build_match(pattern => $pattern, params => $params);
}

sub build_path {
    my $self = shift;

    return 'foo';
}

sub _match_method {
    my $self  = shift;
    my $value = shift;

    return 1 unless defined $self->method;

    return unless defined $value;

    my $methods = $self->method;
    $methods = [$methods] unless ref $methods eq 'ARRAY';

    return !!grep { $_ eq $value } @$methods;
}

sub _build_match { shift; Router::Match->new(@_) }

1;
