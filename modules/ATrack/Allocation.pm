package ATrack::Allocation;

=head1 NAME

ATrack::Allocation - Specimen/Project Allocation object

=head1 SYNOPSIS
    my $alloc = ATrack::Allocation->new($atrack);
    $alloc->add_allocation($project,$specimen);
    $alloc->get_projects_for_specimen($specimen);
    $alloc->get_specimens_for_project($project);

=head1 DESCRIPTION

An object for managing specimen/project allocations. Specimens can belong to
multiple projects. Some projects are direct tracking from a sequencing LIMS,
while others may be arbitrary groupings of specimens based some organisational
structure or based on an actual scientific project.

Code, a direct descendent of VRTrack::Allocations from Jim Stalker and
Vertebrate Resequencing.

=head1 AUTHOR

sm15@sanger.ac.uk

=head1 METHODS

=cut

use strict;
use warnings;
use Carp;
no warnings 'uninitialized';
use constant DBI_DUPLICATE => '1062';

###############################################################################
# Class methods
###############################################################################

=head2 new

  Arg [1]    : database handle to seqtracking database
  Example    : my $allocation = ATrack::Allocation->new($atrack)
  Description: Returns Allocation object
  Returntype : ATrack::Allocation object

=cut

sub new
{
    my ($class,$atrack) = @_;
    die "Need to call with a atrack handle" unless $atrack;
    if ( $atrack->isa('DBI::db') ) { croak "The interface has changed, expected atrack reference.\n"; }
    my $dbh = $atrack->{_dbh};
    my $self = {};
    bless ($self, $class);
    $self->{_dbh} = $dbh;
    $self->{atrack} = $atrack;

    return $self;
}


=head2 add_allocation

  Arg [1]    : project id
  Arg [2]    : specimen id
  Example    : $alloc->add_allocation(5,3);
  Description: Adds an allocation to the database.  Checks if the passed ids
               exist, and fails if they aren't in the database - you should
               check this first and create new entries if required.
  Returntype : ATrack::Allocation object

=cut

sub add_allocation
{
    my ($self,$project,$specimen) = @_;
    my $dbh = $self->{_dbh};
    my $atrack = $self->{atrack};
    my $checkcol = ATrack::Project->new($atrack,$project);
    my $checkind = ATrack::Specimen->new($atrack,$specimen);

    unless ($checkcol && $checkind)
    {
        return 0;
    }

    my $sql = qq[INSERT INTO allocation (project_id, specimen_id) VALUES (?,?)];
    my $sth = $dbh->prepare($sql);
    my $success = 0;
    if ($sth->execute($project,$specimen))
    {
        $success = 1;
    }
    else
    {
        die( sprintf('DB allocation insert failed: %s %s %s', $project, $specimen, $DBI::errstr));
    }
    return $success;
}


=head2 is_allocation_in_database

  Arg [1]    : project id
  Arg [2]    : specimen id
  Example    : $alloc->is_allocation_in_database(5,3);
  Description: Checks to see if the allocation is already present in the
               database.
  Returntype : boolean

=cut

sub is_allocation_in_database
{
    my ($self,$project,$specimen) = @_;
    my $dbh = $self->{_dbh};

    my $sql = qq[SELECT project_id, specimen_id FROM allocation WHERE project_id = ? AND specimen_id = ?];
    my $sth = $dbh->prepare($sql);
    my $already_used = 0;
    if ($sth->execute($project,$specimen))
    {
        my $data = $sth->fetchrow_hashref;
        if ($data)
        {
            $already_used = 1;
        }
    }
    else
    {
        die( sprintf('DB allocation retrieval failed: %s %s %s', $project, $specimen, $DBI::errstr));
    }
    return $already_used;
}


=head2 get_projects_for_specimen

  Arg [1]    : specimen id
  Example    : my @projects = @{$alloc->get_projects_for_specimen(5)};
  Description: get a list of projects that a specimen has been allocated to.
  Returntype : arrayref of ATrack::Project objects

=cut

sub get_projects_for_specimen
{
    my ($self,$specimen) = @_;
    my $dbh = $self->{_dbh};
    my $atrack = $self->{atrack};

    my @projects;
    my $sql = qq[SELECT project_id FROM allocation WHERE specimen_id = ?];
    my $sth = $dbh->prepare($sql);
    if ($sth->execute($specimen))
    {
        foreach(@{$sth->fetchall_arrayref()})
        {
            push @projects, ATrack::Project->new($atrack,$_->[0]);
        }
    }
    else
    {
        die( sprintf('DB allocation retrieval failed: %s %s', $specimen, $DBI::errstr));
    }
    return \@projects;
}

=head2 get_specimens_for_project

  Arg [1]    : project id
  Example    : my @specimens = @{$alloc->get_specimens_for_project(3)};
  Description: get a list of projects that an specimen has been allocated to.
  Returntype : arrayref of ATrack::Specimen objects

=cut

sub get_specimens_for_project
{
    my ($self,$project) = @_;
    my $dbh = $self->{_dbh};
    my $atrack = $self->{atrack};

    my @specimens;
    my $sql = qq[SELECT specimen_id FROM allocation WHERE project_id = ?];
    my $sth = $dbh->prepare($sql);
    if ($sth->execute($project)) {
        foreach(@{$sth->fetchall_arrayref()})
        {
            push @specimens, ATrack::Specimen->new($atrack,$_->[0]);
        }
    }
    else
    {
        die( sprintf('DB allocation retrieval failed: %s %s', $project, $DBI::errstr));
    }
    return \@specimens;
}

1;
