package Router::Pattern;
use Boose;

has 'pattern';
has 'defaults'    => sub { {} };
has 'constraints' => sub { {} };
has 'method';
has 'name';
has 'prefix';

use Router::Match;

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

    my @parts;

    pos $pattern = 0;
    while (pos $pattern < length $pattern) {
        if ($pattern =~ m{ \G \/ }gcxms) {
            $re .= '/';
        }
        elsif ($pattern =~ m{ \G :($TOKEN) }gcxms) {
            my $name = $1;
            my $constraint;
            if (exists $self->constraints->{$name}) {
                $constraint = $self->constraints->{$name};
                $re .= "($constraint)";
            }
            else {
                $re .= '([^\/]+)';
            }

            push @parts,
              { type       => 'capture',
                name       => $name,
                constraint => $constraint ? qr/^$constraint$/ : undef,
                optional   => $par_depth
              };

            push @{$self->{captures}}, $name;
        }
        elsif ($pattern =~ m{ \G \*($TOKEN) }gcxms) {
            my $name = $1;

            $re .= '(.*)';

            push @parts, {type => 'glob', name => $name};

            push @{$self->{captures}}, $name;
        }
        elsif ($pattern =~ m{ \G ($TOKEN) }gcxms) {
            my $text = $1;
            $re .= quotemeta $text;

            push @parts, {type => 'text', text => $text};
        }
        elsif ($pattern =~ m{ \G \( }gcxms) {
            $par_depth++;
            $re .= '(?: ';
        }
        elsif ($pattern =~ m{ \G \) }gcxms) {
            $par_depth--;
            $re .= ' )?';
        }

    }

    if ($par_depth != 0) {
        throw("Parentheses are not balanced in pattern '$pattern'");
    }

    try {
        $re = qr/\A $re \z/xmsi;
    }
    catch {
        throw("Can't compile pattern: '$pattern'");
    };

    $self->{parts} = [@parts];
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
    my $self   = shift;
    my %params = @_;

    $self->compile;

    my @parts;

    my $optional_depth = 0;

    foreach my $part (@{$self->{parts}}) {
        my $type = $part->{type};
        my $name = $part->{name};

        if ($type eq 'capture') {
            if ($part->{optional} && exists $params{$name}) {
                $optional_depth = $part->{optional};
            }

            if (!exists $params{$name}) {
                next
                  if $part->{optional} && $part->{optional} > $optional_depth;

                throw(
                    "Required param '$part->{name}' was not passed when building a path"
                );
            }

            my $param = $params{$name};

            if (defined(my $constraint = $part->{constraint})) {
                throw("Param '$name' fails a constraint")
                  unless $param =~ m/^$constraint$/;
            }

            push @parts, $param;
        }
        elsif ($type eq 'glob') {
            my $name = $part->{name};

            throw(
                "Required glob param '$name' was not passed when building a path"
            ) unless exists $params{$name};

            push @parts, $params{$name};
        }
        elsif ($type eq 'text') {
            push @parts, $part->{text};
        }
    }

    return join '/' => @parts;
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
