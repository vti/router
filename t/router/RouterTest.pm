package RouterTest;

use strict;
use warnings;

use base 'Test::Class';

use Test::More;

use Router;

sub _build_object { shift; Router->new(@_) }

sub empty : Test(3) {
    my $self = shift;

    my $r = $self->_build_object;
    ok $r;
    ok $r->isa('Router');
    ok not defined $r->match('/');
}

sub add_route : Test(1) {
    my $self = shift;

    my $r = $self->_build_object;
    ok $r->add_route('foo');
}

sub unmatched_situations : Test(1) {
    my $self = shift;

    my $r = $self->_build_object;
    $r->add_route('foo//bar');

    ok !$r->match('foo/bar');
}

sub unbalanced_parenthenes : Test(1) {
    my $self = shift;

    my $r = $self->_build_object;
    $r->add_route('((((');

    eval { $r->match('foo/bar') };
    like $@ => qr/are not balanced/;
}

sub match : Test(2) {
    my $self = shift;

    my $r = $self->_build_object;
    $r->add_route('foo');
    $r->add_route(':foo/:bar');

    my $m = $r->match('foo');
    is_deeply $m->get_params => {};

    $m = $r->match('hello/there');
    is_deeply $m->get_params => {foo => 'hello', bar => 'there'};
}

sub match_with_defaults : Test(1) {
    my $self = shift;

    my $r = $self->_build_object;
    $r->add_route('articles',
        defaults => {controller => 'foo', action => 'bar'});

    my $m = $r->match('articles');
    is_deeply $m->get_params => {controller => 'foo', action => 'bar'};
}

sub match_with_defaults_as_string : Test(1) {
    my $self = shift;

    my $r = $self->_build_object;
    $r->add_route('articles', defaults => 'foo#bar');

    my $m = $r->match('articles');
    is_deeply $m->get_params => {controller => 'foo', action => 'bar'};
}

sub match_with_constraints : Test(2) {
    my $self = shift;

    my $r = $self->_build_object;

    $r->add_route('articles/:id', constraints => {id => qr/\d+/});

    my $m = $r->match('articles/abc');
    ok not defined $m;

    $m = $r->match('articles/123');
    is_deeply $m->get_params => {id => 123};
}

sub match_with_optional : Test(2) {
    my $self = shift;

    my $r = $self->_build_object;

    $r->add_route(':year(/:month/:day)');

    my $m = $r->match('2009');
    is_deeply $m->params => {year => 2009, month => undef, day => undef};

    $m = $r->match('2009/12/10');
    is_deeply $m->params => {year => 2009, month => 12, day => 10};
}

sub match_with_optional_nested : Test(3) {
    my $self = shift;

    my $r = $self->_build_object;

    $r->add_route(':year(/:month(/:day))');

    my $m = $r->match('2009');
    is_deeply $m->params => {year => 2009, month => undef, day => undef};

    $m = $r->match('2009/12');
    is_deeply $m->params => {year => 2009, month => 12, day => undef};

    $m = $r->match('2009/12/10');
    is_deeply $m->params => {year => 2009, month => 12, day => 10};
}

sub globbing : Test(4) {
    my $self = shift;

    my $r = $self->_build_object;
    $r->add_route('photos/*other');
    $r->add_route('books/*section/:title');
    $r->add_route('*a/foo/*b');

    my $m = $r->match('photos/foo/bar/baz');
    is_deeply $m->params => {other => 'foo/bar/baz'};

    $m = $r->match('photos/foo/bar/baz');
    is_deeply $m->params => {other => 'foo/bar/baz'};

    $m = $r->match('books/some/section/last-words-a-memoir');
    is_deeply $m->params =>
      {section => 'some/section', title => 'last-words-a-memoir'};

    $m = $r->match('zoo/woo/foo/bar/baz');
    is_deeply $m->params => {a => 'zoo/woo', b => 'bar/baz'};
}

sub method : Test(8) {
    my $self = shift;

    my $r = $self->_build_object;

    $r->add_route('articles');
    ok $r->match('articles');

    $r->add_route('logout', method => 'get');
    ok $r->match('logout', method => 'get');
    ok !$r->match('logout', method => 'post');
    ok !$r->match('logout');

    $r->add_route('photos/:id', method => [qw/get post/]);
    ok !$r->match('photos/1');
    ok $r->match('photos/1', method => 'get');
    ok $r->match('photos/1', method => 'post');
    ok !$r->match('photos/1', method => 'head');
}

sub resource : Test(6) {
    my $self = shift;

    my $r = $self->_build_object;

    $r->add_resource('geocoder');

    my $m = $r->match('geocoder/new', method => 'get');
    is_deeply $m->params => {controller => 'geocoder', action => 'new'};

    $m = $r->match('geocoder', method => 'post');
    is_deeply $m->params => {controller => 'geocoder', action => 'create'};

    $m = $r->match('geocoder', method => 'get');
    is_deeply $m->params => {controller => 'geocoder', action => 'show'};

    $m = $r->match('geocoder/edit', method => 'get');
    is_deeply $m->params => {controller => 'geocoder', action => 'edit'};

    $m = $r->match('geocoder', method => 'put');
    is_deeply $m->params => {controller => 'geocoder', action => 'update'};

    $m = $r->match('geocoder', method => 'delete');
    is_deeply $m->params => {controller => 'geocoder', action => 'destroy'};
}

sub resources : Test(7) {
    my $self = shift;

    my $r = $self->_build_object;

    $r->add_resources('photos');

    my $m = $r->match('photos', method => 'get');
    is_deeply $m->params => {controller => 'photos', action => 'index'};

    $m = $r->match('photos/new', method => 'get');
    is_deeply $m->params => {controller => 'photos', action => 'new'};

    $m = $r->match('photos', method => 'post');
    is_deeply $m->params => {controller => 'photos', action => 'create'};

    $m = $r->match('photos/1', method => 'get');
    is_deeply $m->params =>
      {controller => 'photos', action => 'show', id => 1};

    $m = $r->match('photos/1/edit', method => 'get');
    is_deeply $m->params =>
      {controller => 'photos', action => 'edit', id => 1};

    $m = $r->match('photos/1', method => 'put');
    is_deeply $m->params =>
      {controller => 'photos', action => 'update', id => 1};

    $m = $r->match('photos/1', method => 'delete');
    is_deeply $m->params => {
        controller => 'photos',
        action     => 'destroy',
        id         => 1
    };
}

sub nested_resources : Test(7) {
    my $self = shift;

    my $r = $self->_build_object;

    my $magazines = $r->add_resources('magazines');

    $magazines->add_resources('ads');

    my $m = $r->match('magazines/1/ads', method => 'get');
    is_deeply $m->params => {controller => 'ads', action => 'index'};

    $m = $r->match('magazines/1/ads/new', method => 'get');
    is_deeply $m->params => {controller => 'ads', action => 'new'};

    $m = $r->match('magazines/1/ads', method => 'post');
    is_deeply $m->params => {controller => 'ads', action => 'create'};

    $m = $r->match('magazines/1/ads/1', method => 'get');
    is_deeply $m->params =>
      {controller => 'ads', action => 'show', id => 1};

    $m = $r->match('magazines/1/ads/1/edit', method => 'get');
    is_deeply $m->params =>
      {controller => 'ads', action => 'edit', id => 1};

    $m = $r->match('magazines/1/ads/1', method => 'put');
    is_deeply $m->params =>
      {controller => 'ads', action => 'update', id => 1};

    $m = $r->match('magazines/1/ads/1', method => 'delete');
    is_deeply $m->params => {
        controller => 'ads',
        action     => 'destroy',
        id         => 1
    };
}

sub prefix : Test(3) {
    my $self = shift;

    my $r = $self->_build_object;
    $r->add_route('prefixed', defaults => 'foo#bar', prefix => 'hello');

    my $admin = $r->prefixed_with('admin');
    $admin->add_route('foo', defaults => 'foo#bar');

    ok !$r->match('foo');

    my $m = $r->match('admin/foo');
    is_deeply $m->params => {controller => 'admin-foo', action => 'bar'};

    $m = $r->match('hello/prefixed');
    is_deeply $m->params => {controller => 'hello-foo', action => 'bar'};
}

1;
