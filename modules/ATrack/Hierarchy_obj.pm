package ATrack::Hierarchy_obj;

=head1 NAME

ATrack::Hierarchy_obj - Assembly Tracking Hierarchy_obj object

=head1 SYNOPSIS

=head1 DESCRIPTION

This is the superclass of objects that we model on our storage hierarchy
structure. Hierarchy name is usually a shorter or more user friendly form of
identification for the object or simply replacing spaces or awkward characters
in the regular name. They all have a hierarchy_name() method.

It inherits from Table_obj.

Code, a direct descendent of VRTrack::Hierarchy_obj from Jim Stalker and
Vertebrate Resequencing.

=head1 AUTHOR

sm15@sanger.ac.uk

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
  Description: Returns core objects by id
  Returntype : $class object

=cut

sub new
{
    my ($class, @args) = @_;

    my $self = $class->SUPER::new(@args);

    return $self;
}


=head2 new_by_hierarchy_name

  Arg [1]    : atrack handle to seqtracking database
  Arg [2]    : hierarchy_name
  Arg [3]    : 'current'(default)|datestamp string(in the format returned by
               changed()) (optional)
  Example    : my $obj = ATrack::Hierarchy_obj->new_by_hierarchy_name($atrack, $hierarchy_name)
  Description: Class method. Returns current object by hierarchy_name.  If no
               such hierarchy_name is in the database, returns undef.
               Dies if multiple hierarchy_names match.
  Returntype : ATrack::Hierarchy_obj inheriting object

=cut

sub new_by_hierarchy_name
{
    my ($class, $atrack, $hierarchy_name, @extra_args) = @_;
    confess "Need to call with a atrack handle, hierarchy_name" unless ($atrack && $hierarchy_name);
    return $class->new_by_field_value($atrack, 'hierarchy_name', $hierarchy_name, @extra_args);
}


=head2 hierarchy_name

  Arg [1]    : directory name (optional)
  Example    : my $hname = $project->hierarchy_name();
  Description: Get/set hierarchy name.  This is the directory name
               (without path) that the object will be named in a file hierarchy.
  Returntype : string

=cut

sub hierarchy_name
{
    my $self = shift;
    return $self->_get_set('hierarchy_name', 'string', @_);
}

1;
