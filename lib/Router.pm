package Router;
use Boose;

extends 'Boose::Base';

has 'prefix';

use Router::Pattern;

sub new {
    my $self = shift->SUPER::new(@_);

    $self->{patterns} = [];

    return $self;
}

sub prefixed_with {
    my $self = shift;
    my $prefix = shift;

    my $router = Router->new(prefix => $prefix);
    $router->{patterns} = $self->{patterns};

    return $router;
}

sub add_route {
    my $self    = shift;
    my $pattern = shift;
    my %args = @_;

    $args{prefix} //= $self->prefix;

    $pattern = $self->_build_pattern(pattern => $pattern, %args);

    $self->{patterns} ||= [];
    push @{$self->{patterns}}, $pattern;

    return $self;
}

sub add_resource {
    my $self = shift;
    my $name = shift;

    my $controller = $name;

    $self->add_route("$name/new", method => 'get', defaults => "$controller#new");
    $self->add_route("$name", method => 'post', defaults => "$controller#create");
    $self->add_route("$name", method => 'get',  defaults => "$controller#show");
    $self->add_route("$name/edit", method => 'get', defaults => "$controller#edit");
    $self->add_route("$name", method => 'put', defaults => "$controller#update");
    $self->add_route(
        "$name",
        method   => 'delete',
        defaults => "$name#destroy"
    );

    return $self;
}

sub add_resources {
    my $self = shift;
    my $names = shift;

    $names = [$names] unless ref $names eq 'ARRAY';

    foreach my $name (@$names) {
        $self->add_route("$name", method => 'get', defaults => "$name#index");
        $self->add_route(
            "$name/new",
            method   => 'get',
            defaults => "$name#new"
        );
        $self->add_route(
            "$name",
            method   => 'post',
            defaults => "$name#create"
        );
        $self->add_route(
            "$name/:id",
            method   => 'get',
            defaults => "$name#show"
        );
        $self->add_route(
            "$name/:id/edit",
            method   => 'get',
            defaults => "$name#edit"
        );
        $self->add_route(
            "$name/:id",
            method   => 'put',
            defaults => "$name#update"
        );
        $self->add_route(
            "$name/:id",
            method   => 'delete',
            defaults => "$name#destroy"
        );
    }

    return $self;
}

sub match {
    my $self = shift;
    my $path = shift;
    my @args = @_;

    foreach my $pattern (@{$self->{patterns}}) {
        if (my $m = $pattern->match($path, @args)) {
            return $m;
        }
    }

    return;
}

sub build_path {
    my $self = shift;
    my $name = shift;

    foreach my $pattern (@{$self->{patterns}}) {
        if ($pattern->name eq $name) {
            return $pattern->build_path;
        }
    }

    Carp::croak("Unknown name '$name' used to build a path");
}

sub _build_pattern { shift; Router::Pattern->new(@_) }

1;
