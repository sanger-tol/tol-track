package ATrack::Library_type;

=head1 NAME

ATrack::Library_type - Assembly Tracking Library_type object

=head1 SYNOPSIS
    my $library_type = ATrack::Library_type->new($atrack, $library_type_id);

    my $id      = $library_type->id();
    my $name    = $library_type->name();

=head1 DESCRIPTION

An object describing a library_type, such as DSS or NOPCR. Library_type objects
are usually attached to a ATrack::Library by the library_type_id on the library.

Code, a direct descendent of VRTrack::Library_type from Jim Stalker and
Vertebrate Resequencing.

=head1 AUTHOR

sm15@sanger.ac.uk

=head1 METHODS

=cut

use strict;
use warnings;
use Carp qw(cluck confess);

use base qw(ATrack::Named_obj);


###############################################################################
# Class methods
###############################################################################

=head2 new

  Arg [1]    : database handle to seqtracking database
  Arg [2]    : library_type id
  Example    : my $library_type = ATrack::Library_type->new($atrack, $id)
  Description: Returns Library_type object by library_type_id
  Returntype : ATrack::Library_type object

=cut

sub new
{
    my $class = shift;
    my $self = $class->SUPER::new(@_);
    return $self;
}


=head2 fields_dispatch

  Arg [1]    : none
  Example    : my $fieldsref = $file->fields_dispatch();
  Description: Returns hashref dispatch table keyed on database field
               Used internally for new and update methods
  Returntype : hashref

=cut

sub fields_dispatch
{
    my $self = shift;
    return {
        library_type_id  => sub { $self->id(@_) },
        name             => sub { $self->name(@_) },
        version          => sub { $self->name(@_) },
        enzyme           => sub { $self->name(@_) },
    };
}

=head2 new_by_name

  Arg [1]    : database handle to seqtracking database
  Arg [2]    : library_type name
  Example    : my $lib_type = ATrack::Library_type->new_by_name($atrack, $name)
  Description: Class method. Returns Library_type object by name and project_id.
               If no such name is in the database, returns undef
  Returntype : ATrack::Library_type object

=cut


=head2 create

  Arg [1]    : database handle to seqtracking database
  Arg [2]    : library_type name
  Example    : my $library_type = ATrack::Library_type->create($atrack, $name)
  Description: Class method.  Creates new Library_type object in the database.
  Returntype : ATrack::Library_type object

=cut

sub create
{
    my ($self, $atrack, $name) = @_;
    return $self->SUPER::create($atrack, name => $name);
}


###############################################################################
# Object methods
###############################################################################

=head2 dirty

  Arg [1]    : boolean for dirty status
  Example    : $obj->dirty(1);
  Description: Get/Set for object properties having been altered.
  Returntype : boolean

=cut


=head2 id

  Arg [1]    : id (optional)
  Example    : my $id = $library_type->id();
               $library_type->id('104');
  Description: Get/Set for database ID of a library_type
  Returntype : Internal ID integer

=cut


=head2 name

  Arg [1]    : name (optional)
  Example    : my $name = $library_type->name();
               $library_type->name('CEU');
  Description: Get/Set for library_type name
  Returntype : string

=cut

=head2 version

  Arg [1]    : version (optional)
  Example    : my $version = $library_type->version();
               $library_type->version(104);
  Description: Get/Set for version of a library_type
  Returntype : Internal ID integer

=cut

sub version
{
    my $self = shift;
    return $self->_get_set('version', 'string', @_);
}


=head2 enzyme

  Arg [1]    : enzyme (optional)
  Example    : my $enzyme = $library_type->enzyme();
               $library_type->enzyme('HinfI,DpnII');
  Description: Get/Set for enzyme of a library_type
  Returntype : Internal ID integer

=cut

sub enzyme
{
    my $self = shift;
    return $self->_get_set('enzyme', 'string', @_);
}

=head2 update

  Arg [1]    : None
  Example    : $library_type->update();
  Description: Update a library_type whose properties you have changed. If
               properties haven't changed (i.e. dirty flag is unset) do nothing.
               Unsets the dirty flag on success.
  Returntype : 1 if successful, otherwise undef.

=cut

1;
