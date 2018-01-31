package ATrack::Platform;

=head1 NAME

ATrack::Platform - Assembly Tracking Platform object

=head1 SYNOPSIS
    my $platform = ATrack::Platform->new($atrack, $platform_id);

    my $id      = $platform->id();
    my $name    = $platform->name();
    my $model   = $platform->model();

=head1 DESCRIPTION

An object describing a sequencing platform, such as ILLUMINA or PACBIO or ONT.
Platforms are usually attached to a ATrack::Run by the
platform_id on the run.

=head1 AUTHOR

jws@sanger.ac.uk

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
  Arg [2]    : platform id
  Example    : my $platform = ATrack::Platform->new($atrack, $id)
  Description: Returns Platform object by platform_id
  Returntype : ATrack::Platform object

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
        platform_id  => sub { $self->id(@_) },
        name         => sub { $self->name(@_) },
        model        => sub { $self->model(@_) }
    };
}


=head2 new_by_name

  Arg [1]    : database handle to seqtracking database
  Arg [2]    : platform name
  Example    : my $platform = ATrack::Platform->new_by_name($atrack, $name)
  Description: Class method. Returns Platform object by platform name.  If no such name is in the database, returns undef
  Returntype : ATrack::Platform object

=cut


=head2 create

  Arg [1]    : database handle to seqtracking database
  Arg [2]    : platform name
  Example    : my $platform = ATrack::Platform->create($atrack, $name)
  Description: Class method.  Creates new Platform object in the database.
  Returntype : ATrack::Platform object

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
  Example    : my $id = $platform->id();
               $platform->id('104');
  Description: Get/Set for database ID of a platform
  Returntype : Internal ID integer

=cut


=head2 name

  Arg [1]    : name (optional)
  Example    : my $name = $platform->name();
               $platform->name('SLX');
  Description: Get/Set for platform name
  Returntype : string

=cut

=head2 model

  Arg [1]    : model (optional)
  Example    : my $model = $platform->version();
               $platform->model('HiSeqX');
  Description: Get/Set for model of a platform
  Returntype : Internal ID integer

=cut

sub model
{
    my $self = shift;
    return $self->_get_set('model', 'string', @_);
}


=head2 update

  Arg [1]    : None
  Example    : $platform->update();
  Description: Update a platform whose properties you have changed.  If properties haven't changed (i.e. dirty flag is unset) do nothing.
               Unsets the dirty flag on success.
  Returntype : 1 if successful, otherwise undef.

=cut

1;
