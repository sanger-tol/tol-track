package ATrack::Named_obj;

=head1 NAME

ATrack::Named_obj - Assembly Tracking Named_obj object

=head1 SYNOPSIS

=head1 DESCRIPTION

This is the superclass of objects that have the concept of a 'name' which is
unique.

=head1 AUTHOR

jws@sanger.ac.uk

=head1 METHODS

=cut

use strict;
use warnings;
use Carp qw(cluck confess);

use base qw(ATrack::Table_obj);


=head2 new

  Arg [1]    : atrack handle
  Arg [2]    : obj id
  Example    : my $obj= $class->new($atrack, $id)
  Description: Returns objects by id
  Returntype : $class object

=cut

sub new
{
    my ($class, @args) = @_;

    my $self = $class->SUPER::new(@args);

    return $self;
}


=head2 new_by_name

  Arg [1]    : atrack handle to seqtracking database
  Arg [2]    : name
  Arg [3]    : 'current'(default)|datestamp string(in the format returned by
               changed()) (optional)
  Example    : my $obj = ATrack::Named_obj->new_by_name($atrack, $name);
  Description: Class method. Returns current object by name. If no such name is
               in the database, returns undef.
  Returntype : ATrack::Named_obj inheriting object

=cut

sub new_by_name
{
    my ($class, $atrack, $name, @extra_args) = @_;
    confess "Need to call with a atrack handle, name" unless ($atrack && $name);
    return $class->new_by_field_value($atrack, 'name', $name, @extra_args);
}


=head2 name

  Arg [1]    : name (optional)
  Example    : my $name = $project->name();
  Description: Get/set name.
  Returntype : string

=cut

sub name
{
    my $self = shift;
    return $self->_get_set('name', 'string', @_);
}

1;
