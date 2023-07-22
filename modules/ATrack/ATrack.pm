package ATrack::ATrack;

=head1 NAME

ATrack::ATrack - Assembly Tracking container

=head1 SYNOPSIS
    my $track = ATrack::ATrack->new();

    # get arrayref of studies being tracked for traversing hierarchy
    my $projects = $track->projects();

    # also provides accessors for arbitrary objects in hierarchy
    my $seq = $track->get_seq_by_id
    my $lane = $track->get_seq_by_filename

=head1 DESCRIPTION

Retrieves/adds projects in the sequencing tracking database.

Code, a direct descendent of VRTrack::VRTrack from Jim Stalker and Vertebrate
Resequencing.

==head1 NOTES

A mysql database required. The schema is mysql specific, so other drivers cannot
be used instead.

=head1 AUTHOR

sm15@sanger.ac.uk

=head1 METHODS

=cut

use strict;
use warnings;
use Carp qw(confess croak cluck);
no warnings 'uninitialized';
use DBI;
use File::Spec;
use ATrack::Specimen;
use ATrack::Sample;
use ATrack::Library;
use ATrack::Seq;
use ATrack::Core_obj;
use ATrack::History;

use constant SCHEMA_VERSION => '1';

our $DEFAULT_PORT = 3306;

our @schema_sql;

=head2 new

  Arg [1]    : hashref of {database, host, port, user, password}
               connection details. port defaults to 3306.
  Example    : my $track = ATrack::ATrack->new()
  Description: Returns ATrack object if can connect to database
  Returntype : ATrack::ATrack object

=cut

sub new
{
    my ($class, $dbparams) = @_;

    my $self = {};
    bless ($self, $class);
    $dbparams->{port} ||= $DEFAULT_PORT;
    my $dbh = DBI->connect(
        "DBI:mysql:host=$dbparams->{host};".
        "port=$dbparams->{port};".
        "database=$dbparams->{database};",
        $dbparams->{'user'},
        $dbparams->{'password'},
        { 'RaiseError' => 0, 'PrintError'=>0 }
    );

    if ($DBI::err)
    {
          warn(sprintf('DB connection failed: %s', $DBI::errstr));
          return undef;
    }

    $self->{_db_params} = $dbparams;
    $self->{_dbh} = $dbh;
    $self->{transaction} = 0;

    $dbh->{RaiseError} = 1;
    $dbh->{PrintError} = 1;

    # Check version is OK.
    my $schema_version = $self->schema_version();
    unless ($schema_version == SCHEMA_VERSION)
    {
        warn(sprintf('wrong schema version. API is %s, DB is %s', SCHEMA_VERSION, $schema_version));
        return undef;
    }

    return $self;
}

=head2 schema

  Arg [1]    : n/a
  Example    : foreach (ATrack::ATrack->schema()) { print; }
  Description: Get an array of sql lines suitable for printing out and streaming
               into your database to (drop and then) create all the ATrack
               tables. WARNING: using these sql lines on an existing database
               will DESTROY ALL DATA!
  Returntype : array of ;\n termianted sql strings

=cut

sub schema
{
    return @schema_sql if @schema_sql;

    my $line = '';
    while (<DATA>)
    {
        chomp;
        next if /^--/;
        next unless /\S/;
        $line .= $_;
        if (/;\s*$/)
        {
            push(@schema_sql, $line."\n");
            $line = '';
        }
    }
    if ($line =~ /;\s*$/)
    {
        push(@schema_sql, $line);
    }

    return @schema_sql;
}

=head2 schema_version

  Arg [1]    : None
  Example    : my $schema_version = $project->schema_version();
  Description: Returns database schema_version
  Returntype : int

=cut

sub schema_version
{
    my ($self) = @_;

    my $sql = qq[SELECT schema_version FROM schema_version];
    my $sth = $self->{_dbh}->prepare($sql);

    my $schema_version;
    if ($sth->execute())
    {
        $schema_version = $sth->fetchrow_array();
    }
    else
    {
        die(sprintf('Cannot retrieve schema_version: %s', $DBI::errstr));
    }

    return $schema_version;
}


=head2 projects

  Arg [1]    : None
  Example    : my $projects = $track->projects();
  Description: Returns a ref to an array of the Project objects that are being
               tracked
  Returntype : ref to array of ATrack::Project objects

=cut

sub projects
{
    my ($self) = @_;

    # removed cache here, otherwise we would have a reference to a bunch
    # of objects that had a reference back to us.  Bad thing.
    my @projects;
    foreach my $id (@{$self->projects_ids()})
    {
        my $obj = ATrack::Project->new($self,$id);
        push @projects, $obj;
    }
    return \@projects;
}


=head2 project_ids

  Arg [1]    : None
  Example    : my $project_ids = $project->projects_ids();
  Description: Returns a ref to an array of the project IDs that are being
               tracked
  Returntype : ref to array of integer project IDs

=cut

sub project_ids
{
    my ($self) = @_;

    unless ($self->{'project_ids'})
    {
        my $history_sql = ATrack::Core_obj->_history_sql;
        my $sql = qq[SELECT DISTINCT(project_id) FROM project WHERE 1=1 $history_sql];
        my @projects;
        my $sth = $self->{_dbh}->prepare($sql);

        if ($sth->execute())
        {
            foreach(@{$sth->fetchall_arrayref()})
            {
                push @projects, $_->[0];
            }
        }
        else
        {
            die(sprintf('Cannot retrieve projects: %s', $DBI::errstr));
        }
        $self->{'project_ids'} = \@projects;
    }

    return $self->{'project_ids'};
}


=head2 add_project

  Arg [1]    : study name
  Example    : my $newproject = $track->add_project('Lepidoptera');
  Description: create a new study, and if successful, return the object
  Returntype : ATrack::Project object

=cut

sub add_project
{
    my ($self, $name) = @_;
    my $dbh = $self->{_dbh};

    # project names should not be added twice
    my $obj = $self->get_project_by_name($name);
    if ($obj)
    {
        warn "Project $name is already present in the database\n";
        return undef;
    }

    $obj = ATrack::Project->create($self,$name);
    delete $self->{'project_ids'};
    return $obj;
}


=head2 get_project_by_name

  Arg [1]    : project name
  Example    : my $project = $track->get_project_by_name('My project');
  Description: retrieve project object by name
  Returntype : ATrack::Study object

=cut

sub get_project_by_name
{
    my ($self, $name) = @_;
    my $obj = ATrack::Project->new_by_name($self,$name);
    return $obj;
}


=head2 get_project_by_id

  Arg [1]    : project internal id
  Example    : my $project = $track->get_project_by_id(140);
  Description: retrieve project object by internal id
  Returntype : ATrack::Study object

=cut

sub get_project_by_id
{
    my ($self, $id) = @_;
    my $obj = ATrack::Project->new($self,$id);
    return $obj;
}


=head2 get_project_by_lims_id

  Arg [1]    : project LIMS id
  Example    : my $project = $track->get_project_by_lims_id(140);
  Description: retrieve project object by LIMS id
  Returntype : ATrack::Project object

=cut

sub get_project_by_lims_id
{
    my ($self, $id) = @_;
    my $obj = ATrack::Project->new_by_lims_id($self,$id);
    return $obj;
}

=head2 seq_info

 Title   : seq_info
 Usage   : my %info = $obj->seq_info('seq_name');
 Function: Get information about a Seq from the database.
 Returns : hash of information, with keys:
           hierarchy_path => string,
           study          => string, (the true project code)
           project        => string, (may not be the true project code)
           sample         => string,
           individual     => string,
           individual_alias => string,
           individual_acc => string,
           individual_coverage => float, (the coverage of this lane's individual)
           population     => string,
           technology     => string, (aka platform, the way DCC puts it, eg.
                                      'ILLUMINA' instead of 'SLX')
           seq_tech       => string, (aka platform, the way Sanger puts it, eg.
                                      'SLX' instead of 'ILLUMINA')
           library        => string, (the hierarchy name, which is most likely
                                      similar to the true original library name)
           library_raw    => string, (the name stored in the database, which may
                                      be a uniquified version of the original
                                      library name)
           library_true   => string, (an attempt at getting the true original
                                      library name, as it was before it was
                                      munged in various ways to create library
                                      and library_raw)
           lane           => string, (aka read group)
           centre         => string, (the sequencing centre name)
           species        => string, (may be undef)
           insert_size    => int, (can be undef if this lane is single-ended)
           withdrawn      => boolean,
           imported       => boolean,
           mapped         => boolean,
           aseq           => ATrack::Seq object
           (returns undef if lane name isn't in the database)
 Args    : lane name (read group) OR a ATrack::Seq object.

           optionally, pre_swap => 1 to get info applicable to the lane in its
           state immediately prior to the last time is_processed('swapped', 1)
           was called on it.

           optionally, get_coverage => 1 to calculate (can be very slow!)
           individual_coverage. To configure this, supply the optional args
           understood by individual_coverage()

=cut

# sub seq_info {
#     my ($atrack, $lane, %args) = @_;

#     my $hist = ATrack::History->new();
#     my $orig_time_travel = $hist->time_travel;

#     my ($rg, $vrlane);
#     if (ref($lane) && $lane->isa('ATrack::Lane')) {
#         $vrlane = $lane;
#         $rg = $vrlane->hierarchy_name;
#         $lane = $rg;
#     }
#     else {
#         $vrlane = ATrack::Lane->new_by_hierarchy_name($atrack, $lane);
#         $rg = $lane;
#     }

#     return unless ($rg && $vrlane);

#     my $datetime = 'latest';
#     if ($args{pre_swap}) {
#         $datetime = $hist->was_processed($vrlane, 'swapped');
#     }
#     # make sure we've got a lane of the correct time period
#     $hist->time_travel($datetime);
#     $vrlane = ATrack::Lane->new_by_hierarchy_name($atrack, $lane) || confess("Could not get a vrlane with name $lane prior to $datetime");

#     my %info = (lane => $rg, vrlane => $vrlane);

#     $info{hierarchy_path} = $atrack->hierarchy_path_of_lane($vrlane);
#     $info{withdrawn} = $vrlane->is_withdrawn;
#     $info{imported} = $vrlane->is_processed('import');
#     $info{mapped} = $vrlane->is_processed('mapped');

#     my %objs = $atrack->lane_hierarchy_objects($vrlane);

#     $info{insert_size} = $objs{library}->insert_size;
#     $info{library} = $objs{library}->hierarchy_name || confess("library hierarchy_name wasn't known for $rg");
#     my $lib_name = $objs{library}->name || confess("library name wasn't known for $rg");
#     $info{library_raw} = $lib_name;
#     ($lib_name) = split(/\|/, $lib_name);
#     $info{library_true} = $lib_name;
#     $info{centre} = $objs{centre}->name || confess("sequencing centre wasn't known for $rg");
#     my $seq_tech = $objs{platform}->name || confess("sequencing platform wasn't known for $rg");
#     $info{seq_tech} = $seq_tech;
#     if ($seq_tech =~ /illumina|slx/i) {
#         $info{technology} = 'ILLUMINA';
#     }
#     elsif ($seq_tech =~ /solid/i) {
#         $info{technology} = 'ABI_SOLID';
#     }
#     elsif ($seq_tech =~ /454/) {
#         $info{technology} = 'LS454';
#     }
#     $info{sample} = $objs{sample}->name || confess("sample name wasn't known for $rg");
#     $info{individual} = $objs{individual}->name || confess("individual name wasn't known for $rg");
#     $info{individual_alias} = $objs{individual}->alias;
#     $info{species} =  $objs{species}->name if $objs{species};#|| $self->throw("species name wasn't known for $rg");
#     $info{individual_acc} = $objs{individual}->acc; # || $self->throw("sample accession wasn't known for $rg");
#     if ($args{get_coverage}) {
#         $info{individual_coverage} = $atrack->hierarchy_coverage(individual => [$info{individual}],
#                                                                   $args{genome_size} ? (genome_size => $args{genome_size}) : (),
#                                                                   $args{gt_confirmed} ? (gt_confirmed => $args{gt_confirmed}) : (),
#                                                                   $args{qc_passed} ? (qc_passed => $args{qc_passed}) : (),
#                                                                   $args{mapped} ? (mapped => $args{mapped}) : ());
#     }
#     $info{population} = $objs{population}->name;
#     $info{project} = $objs{project}->name;
#     $info{study} = $objs{study} ? $objs{study}->acc : $info{project};

#     $hist->time_travel($orig_time_travel);

#     return %info;
# }

=head2 seq_hierarchy_objects

 Title   : seq_hierarchy_objects
 Usage   : my %objects = $obj->seq_hierarchy_objects($lane);
 Function: Get all the parent objects of a seq, from the library up to the
           project.
 Returns : hash with these key and value pairs:
           sample => ATrack::Sample object
           individual => ATrack::Individual object
           population => ATrack::Population object
           platform => ATrack::Seq_tech object
           centre => ATrack::Seq_centre object
           library => ATrack::Library object
           species => ATrack::Species object
 Args    : ATrack::Lane object

=cut

sub seq_hierarchy_objects
{
    my ($atrack, $seq) = @_;

    my $lib = ATrack::Library->new($atrack, $seq->library_id);
    my $seq = ATrack::Seq->new($atrack, $seq->seq_id);
    my $centre = $seq->centre;
    my $platform = $seq->platform;
    my $sample = ATrack::Sample->new($atrack, $seq->sample_id);
    my $specimen = $sample->specimen;
    my $species = $specimen->species;

    return (
        sample => $sample,
        seq => $seq,
        specimen => $specimen,
        platform => $platform,
        centre => $centre,
        library => $lib,
        species => $species
    );
}

=head2 get_seqs

 Title   : get_seqs
 Usage   : my @lanes = $obj->get_seqs(sample => ['NA19239']);
 Function: Get all the lanes under certain parts of the hierarchy, excluding
           withdrawn lanes.
 Returns : list of ATrack::Lane objects
 Args    : At least one hierarchy level as a key, and an array ref of names
           as values, eg. sample => ['NA19239'], platform => ['SLX', '454'].
           Valid key levels are project, sample, individual, population,
           platform, centre, library and species. (With no options at all, all
           active lanes in the database will be returned)
           Alternatively to supplying hierarchy level keys and array refs of
           allowed values, you can supply *_regex keys with regex string values
           to select all members of that hierarchy level that match the regex,
           eg. project_regex => 'low_coverage' to limit to projects with
           "low_coverage" in the name. _regex only applies to project, sample
           and library.

           By default it won't return withdrawn lanes; change that:
           return_withdrawn => bool

=cut

sub get_seqs
{
    my ($atrack, %args) = @_;

    my @good_lanes;
    foreach my $project (@{$atrack->projects})
    {
        my $ok = 1;
        if (defined $args{project})
        {
            $ok = 0;
            foreach my $name (@{$args{project}})
            {
                if ($name eq $project->name || $name eq $project->hierarchy_name || ($project->study && $name eq $project->study->acc))
                {
                    $ok = 1;
                    last;
                }
            }
        }
        $ok || next;
        if (defined $args{project_regex})
        {
            $project->name =~ /$args{project_regex}/ || next;
        }

        foreach my $sample (@{$project->samples})
        {
            my $ok = 1;
            if (defined ($args{sample}))
            {
                $ok = 0;
                foreach my $name (@{$args{sample}})
                {
                    if ($name eq $sample->name)
                    {
                        $ok = 1;
                        last;
                    }
                }
            }
            $ok || next;
            if (defined $args{sample_regex})
            {
                $sample->name =~ /$args{sample_regex}/ || next;
            }

            my %objs;
            $objs{individual} = $sample->individual;
            $objs{individual} || next; # if there was some import failure we might have ended up with a sample row but no individual
            $objs{population} = $objs{individual}->population;
            $objs{species}    = $objs{individual}->species;

            my ($oks, $limits) = (0, 0);
            foreach my $limit (qw(individual population species))
            {
                if (defined $args{$limit}) {
                    $limits++;
                    if ($limit eq 'species' && !(defined $objs{'species'}))
                    {
                        confess('species not defined for sample '.$sample->name);
                        last;
                    }
                    my $ok = 0;
                    foreach my $name (@{$args{$limit}})
                    {
                        if ($name eq $objs{$limit}->name || ($objs{$limit}->can('hierarchy_name') && $name eq $objs{$limit}->hierarchy_name))
                        {
                            $ok = 1;
                            last;
                        }
                    }
                    $oks += $ok;
                }
            }
            next unless $oks == $limits;

            foreach my $library (@{$sample->libraries})
            {
                my $ok = 1;
                if (defined ($args{library}))
                {
                    $ok = 0;
                    foreach my $name (@{$args{library}})
                    {
                        if ($name eq $library->name || $name eq $library->hierarchy_name)
                        {
                            $ok = 1;
                            last;
                        }
                    }
                }
                $ok || next;
                if (defined $args{library_regex})
                {
                    $library->name =~ /$args{library_regex}/ || next;
                }

                my %objs;
                $objs{centre} = $library->seq_centre;
                $objs{platform} = $library->seq_tech;

                my ($oks, $limits) = (0, 0);
                foreach my $limit (qw(centre platform))
                {
                    if (defined $args{$limit})
                    {
                        $limits++;
                        my $ok = 0;
                        foreach my $name (@{$args{$limit}})
                        {
                            if ($name eq $objs{$limit}->name)
                            {
                                $ok = 1;
                                last;
                            }
                        }
                        $oks += $ok;
                    }
                }
                next unless $oks == $limits;

                push(@good_lanes, @{$library->lanes});
            }
        }
    }

    if ($args{return_withdrawn})
    {
        return @good_lanes;
    }
    else
    {
        # filter out withdrawn lanes
        my @active;
        foreach my $lane (@good_lanes)
        {
            next if $lane->is_withdrawn;
            push(@active, $lane);
        }
        return @active;
    }
}

=head2 transaction

  Arg [1]    : Code ref
  Arg [2]    : optional hash ref: { read => [], write => []} where the array
               ref values contain table names to lock for reading/writing
               [NB: not yet implemented]
  Arg [3]    : optional array ref of objects to make sure they really get
               updated in the database
  Example    : my $worked = $atrack->transaction(sub { $seq->update; },
                                                     { write => ['seq'] });
  Description: Run code safely in a transaction, with automatic retries in the
               case of deadlocks. If the transaction fails for some other
               reason, the error message can be found in
               $atrack->{transaction_error}.
  Returntype : Boolean

=cut

sub transaction
{
    my ($self, $code, $locks, $objects) = @_;

    my $dbh = $self->{_dbh};

    # we wanted to use begin_work() to handle turning off and on AutoCommit, but
    # to be compatible with transaction_start() et al. we'll have to use the
    # same mechanisms
    my $autocommit = $dbh->{AutoCommit};
    $dbh->{AutoCommit} = 0;
    $self->{transaction}++;

    # Raise Errors if there are any problems, which we will catch in evals
    my $raiseerror = $dbh->{RaiseError};
    $dbh->{RaiseError} = 1;

    if ($self->{transaction} > 1)
    {
        &$code;
        $self->{transaction}--;
        return 1;
    }

    # turn off warnings that may be generated when we call &$code
    my $sig_warn = $SIG{'__WARN__'};
    $SIG{'__WARN__'} = sub { };

    # try to run the $code and commit, repeating if deadlock found, die with
    # stack trace for other issues
    my $success = 0;
    delete $self->{transaction_error};
    while (1)
    {
        eval
        {
            # make extra sure RaiseError and AutoCommit are set as necessary,
            # incase something nested changes these
            $dbh->{RaiseError} = 1;
            $dbh->{AutoCommit} = 0;
            &$code;
            $dbh->{RaiseError} = 1;
            $dbh->{AutoCommit} = 0;
            $dbh->commit;
        };
        if ($@)
        {
            my $err = $@;
            eval { $dbh->rollback };
            if ($err =~ /Deadlock found/)
            {
                sleep(2);
            }
            else
            {
                chomp($err);
                $self->{transaction_error} = "Transaction failed, rolled back. Error was: $err";
                last;
            }
        }
        else
        {
            $success = 1;
            if ($objects)
            {
                OBJLOOP: foreach my $obj (@$objects)
                {
                    next unless $obj;

                    # really make sure that the database values match the
                    # instance values
                    $obj->can('fields_dispatch') || next;
                    my %expected_fields = %{$obj->fields_dispatch || {}};
                    my @fields = keys %expected_fields;
                    my $retries = 0;
                    while (1)
                    {
                        my $fresh_atrack = ATrack::ATrack->new($self->{_db_params});
                        my $fresh_obj = $obj->new($fresh_atrack, $obj->id);
                        my %db_fields = %{$fresh_obj->fields_dispatch || {}};
                        my $all_matched = 1;
                        foreach my $field (@fields)
                        {
                            my $expected_val = &{$expected_fields{$field}}();
                            my $db_val = &{$db_fields{$field}}();
                            if ($db_val ne $expected_val)
                            {
                                $fresh_obj->$field($expected_val);
                                $all_matched = 0;
                            }
                        }

                        unless ($all_matched)
                        {
                            $fresh_atrack->transaction(sub { $fresh_obj->update; });
                        }

                        last if $all_matched;
                        if ($retries++ >= 10)
                        {
                            $self->{transaction_error} = "Unable to make the database values match instance values after using update() on object $obj with id ".$obj->id."\n";
                            $success = 0;
                            last OBJLOOP;
                        }
                    }
                }
            }
            last;
        }
    }

    $dbh->{AutoCommit} = $autocommit;
    $dbh->{RaiseError} = $raiseerror;
    $SIG{'__WARN__'} = $sig_warn;
    $self->{transaction}--;

    return $success;
}

=head2 transaction_start

  Arg [1]    : None
  Example    : $atrack->transaction_start();
  Description:
  Returntype : none

=cut

sub transaction_start
{
    my ($self) = @_;

    my $dbh = $self->{_dbh};

    $self->{transaction}++;                    # Increase the counter
    if ( $self->{transaction}>1 ) { return; }  # If already inside a transaction, we are done.

    $self->{_AutoCommit} = $dbh->{AutoCommit}; # Remember the previous state
    $dbh->{AutoCommit} = 0;                    # Start the transaction

    return;
}


=head2 transaction_commit

  Arg [1]    : None
  Example    : $atrack->transaction_commit();
  Description:
  Returntype : none

=cut

sub transaction_commit
{
    my ($self) = @_;

    die "transaction_commit: no active transaction\n" unless $self->{transaction}>0;

    $self->{transaction}--;
    if ( $self->{transaction} ) { return; } # If inside a nested transactions, don't commit yet.

    $self->{_dbh}->commit;
    $self->{_dbh}->{AutoCommit} = $self->{_AutoCommit};

    return;
}


=head2 transaction_rollback

  Arg [1]    : None
  Example    : $atrack->transaction_rollback();
  Description:
  Returntype : none

=cut

sub transaction_rollback
{
    my ($self) = @_;

    die "transaction_commit: no active transaction\n" unless $self->{transaction}>0;

    $self->{transaction}--;

    # roll back within eval to prevent rollback
    # failure from terminating the script
    eval { $self->{_dbh}->rollback; };

    $self->{_dbh}->{AutoCommit} = $self->{_AutoCommit};

    # If inside a nested transaction, return the control higher
    if ( $self->{transaction} ) { die "Transaction failed\n"; }

    return;
}


=head2 atrack

  Arg [1]    : None
  Example    : my $atrack = $obj->atrack();
  Description: Get atrack. This is self, as we _are_ a ATrack object. This call
               is just to provide consistency to getting new objects through
               the api by my $sub = ATrack::Whatever($parent->atrack, $id);
  Returntype : ATrack::ATrack

=cut

sub atrack
{
    my ($self) = @_;
    return $self;
}

=head2 database_params

  Arg [1]    : None
  Example    : my $parms = $obj->database_params();
  Description: Get the database parameters that were supplied to new() to create
               this instance of ATrack::ATrack.
  Returntype : hash ref

=cut

sub database_params
{
    my $self = shift;
    return $self->{_db_params};
}


=head2 specimen_names

  Arg [1]    : None
  Example    : my @specimens = $atrack->specimen_names();
  Description: Returns a reference to an array of the names in the specimen
               table sorted by name
  Returntype : reference to array of strings

=cut

sub specimen_names
{
    my $self = shift;
    return $self->_list_names('specimen');
}

=head2 species_names

  Arg [1]    : None
  Example    : my @species = $atrack->species_names();
  Description: Returns a reference to an array of the names in the species table
               sorted by name
  Returntype : reference to array of strings

=cut

sub species_names
{
    my $self = shift;
    return $self->_list_names('species');
}

=head2 centre_names

  Arg [1]    : None
  Example    : my @centres = $atrack->centre_names();
  Description: Returns a reference to an array of the distinct names in the
               centre table
  Returntype : reference to array of strings

=cut

sub centre_names
{
    my $self = shift;
    return $self->_list_names('centre');
}

=head2 platform_names

  Arg [1]    : None
  Example    : my @platforms = $atrack->platform_names();
  Description: Returns a reference to an array of the distinct names in the
               platform table
  Returntype : reference to array of strings

=cut

sub platform_names
{
    my $self = shift;
    return $self->_list_names('platform');
}

=head2 library_type_names

  Arg [1]    : None
  Example    : my @lib_types = $atrack->library_type_names();
  Description: Returns a reference to an array of the distinct names in the
               library_type table
  Returntype : reference to array of strings

=cut

sub library_type_names
{
    my $self = shift;
    return $self->_list_names('library_type');
}


# Returns reference to an array of names contained in the name column of a table
# Tables are restricted to tables contained in hash %permitted_table within the
# function.
sub _list_names
{
    my ($self,$table) = @_;

    # List of permitted tables
    # If 1, then add 'DISTINCT' and 'WHERE current = 1' tp SQL query
    my %permitted_table = (
        species => 1,
        specimen => 1,
        project => 0,
        platform => 0,
        centre => 0,
        library_type => 0
    );

    unless( exists $permitted_table{$table} ) { croak qq[The listing names for '$table' not permitted]; }
    my $distinct = $permitted_table{$table} ? 'DISTINCT' : '';
    my $current = $permitted_table{$table} ? 'WHERE current = 1' : '';

    my @names;
    my $sql = qq[select $distinct $table.name from $table $current order by $table.name;];

    my $sth = $self->{_dbh}->prepare($sql);

    my $tmpname;
    if ($sth->execute())
    {
        $sth->bind_columns ( \$tmpname );
        push @names, $tmpname while $sth->fetchrow_arrayref;
    }
    else
    {
        die(sprintf('Cannot retrieve $table names: %s', $DBI::errstr));
    }

    return \@names;
}


1;


__DATA__
--
-- Table structure for table `version`
--

DROP TABLE IF EXISTS `schema_version`;
CREATE TABLE `schema_version` (
  `schema_version` mediumint(8) unsigned NOT NULL,
  PRIMARY KEY  (`schema_version`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

insert into schema_version(schema_version) values (1);

--
-- Table structure for table `species`
--

DROP TABLE IF EXISTS `species`;
CREATE TABLE `species` (
  `row_id` int unsigned NOT NULL AUTO_INCREMENT,
  `species_id` mediumint(8) unsigned NOT NULL DEFAULT 0,
  `name` varchar(255) NOT NULL,
  `hierarchy_name` varchar(255) NOT NULL DEFAULT '',
  `strain` varchar(40) DEFAULT NULL,
  `common_name` varchar(255) DEFAULT NULL,
  `taxon_id` mediumint(8) DEFAULT NULL,
  `taxon_family` varchar(40) DEFAULT NULL,
  `taxon_order` varchar(40) DEFAULT NULL,
  `taxon_phylum` varchar(40) DEFAULT NULL,
  `taxon_group` varchar(40) DEFAULT NULL,
  `genome_size` float unsigned DEFAULT NULL,
  `chromosome_number` mediumint(8) DEFAULT NULL,
  `note_id` mediumint(8) unsigned DEFAULT NULL,
  `changed` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `current` tinyint(1) DEFAULT '0',
  PRIMARY KEY (`row_id`),
  UNIQUE KEY `name` (`name`,`strain`),
  KEY `species_id` (`species_id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

--
-- Table structure for table `specimen`
--

DROP TABLE IF EXISTS `specimen`;
CREATE TABLE `specimen` (
  `row_id` int unsigned NOT NULL AUTO_INCREMENT,
  `specimen_id` int(10) unsigned NOT NULL DEFAULT 0,
  `name` varchar(255) NOT NULL DEFAULT '',
  `hierarchy_name` varchar(255) NOT NULL DEFAULT '',
  `species_id` mediumint(8) unsigned DEFAULT NULL,
  `lims_id` varchar(255) NOT NULL DEFAULT '',
  `supplier_name` varchar(40) NOT NULL DEFAULT '',
  `accession_id` int(10) unsigned NOT NULL DEFAULT 0,
  `sex_id` smallint(5) unsigned DEFAULT NULL,
  `ploidy` int(1) unsigned NOT NULL DEFAULT 0,
  `karyotype` varchar(255) NOT NULL DEFAULT '',
  `father_id` int(10) unsigned DEFAULT NULL,
  `mother_id` int(10) unsigned DEFAULT NULL,
  `note_id` mediumint(8) unsigned DEFAULT NULL,
  `changed` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `current` tinyint(1) DEFAULT '0',
  PRIMARY KEY (`row_id`),
  UNIQUE KEY `name` (`name`),
  KEY  (`specimen_id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

--
-- Table structure for table `sex`
--

DROP TABLE IF EXISTS `sex`;
CREATE TABLE `sex` (
  `sex_id` smallint(5) unsigned NOT NULL AUTO_INCREMENT,
  `name` varchar(255) NOT NULL DEFAULT '',
  PRIMARY KEY  (`sex_id`),
  UNIQUE KEY `name` (`name`),
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

--
-- Table structure for table `project`
--

DROP TABLE IF EXISTS `project`;
CREATE TABLE `project` (
  `project_id` smallint(5) unsigned NOT NULL AUTO_INCREMENT,
  `name` varchar(255) NOT NULL DEFAULT '',
  `hierarchy_name` varchar(255) NOT NULL DEFAULT '',
  `lims_id` varchar(255) NOT NULL DEFAULT '',
  `accession_id` int(10) unsigned NOT NULL DEFAULT 0,
  PRIMARY KEY  (`project_id`),
  UNIQUE KEY `name` (`name`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

--
-- Table structure for table `allocation`
--

DROP TABLE IF EXISTS `allocation`;
CREATE TABLE `allocation` (
  `project_id` smallint(5) unsigned NOT NULL DEFAULT '0',
  `specimen_id` int(10) unsigned NOT NULL DEFAULT '0',
  `is_primary` tinyint(1) DEFAULT '0',
  PRIMARY KEY (`project_id`,`specimen_id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

--
-- Table structure for table `sample`
--

DROP TABLE IF EXISTS `sample`;
CREATE TABLE `sample` (
  `row_id` int unsigned NOT NULL AUTO_INCREMENT,
  `sample_id` smallint(5) unsigned NOT NULL DEFAULT '0',
  `name` varchar(255) NOT NULL DEFAULT '',
  `hierarchy_name` varchar(40) NOT NULL DEFAULT '',
  `specimen_id` smallint(5) unsigned DEFAULT NULL,
  `lims_id` mediumint(8) unsigned DEFAULT NULL,
  `accession_id` int(10) unsigned NOT NULL DEFAULT 0,
  `note_id` mediumint(8) unsigned DEFAULT NULL,
  `changed` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `current` tinyint(1) DEFAULT '0',
  PRIMARY KEY (`row_id`),
  KEY  (`sample_id`),
  KEY `lims_id` (`lims_id`),
  KEY `current` (`current`),
  KEY `name` (`name`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

--
-- Table structure for table `library`
--

DROP TABLE IF EXISTS `library`;
CREATE TABLE `library` (
  `row_id` int unsigned NOT NULL AUTO_INCREMENT,
  `library_id` int(10) NOT NULL DEFAULT '0',
  `name` varchar(255) NOT NULL DEFAULT '',
  `hierarchy_name` varchar(40) NOT NULL DEFAULT '',
  `library_type_id` smallint(5) unsigned DEFAULT NULL,
  `lims_id` mediumint(8) unsigned DEFAULT NULL,
  `note_id` mediumint(8) unsigned DEFAULT NULL,
  `changed` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `current` tinyint(1) DEFAULT '0',
  PRIMARY KEY (`row_id`),
  KEY `name` (`name`),
  KEY `lims_id` (`lims_id`),
  KEY `library_id` (`library_id`),
  KEY `library_type_id` (`library_type_id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

--
-- Table structure for table `library_type`
--

DROP TABLE IF EXISTS `library_type`;
CREATE TABLE `library_type` (
  `library_type_id` smallint(5) unsigned NOT NULL AUTO_INCREMENT,
  `name` varchar(255) NOT NULL DEFAULT '',
  `hierarchy_name` varchar(255) NOT NULL DEFAULT '',
  `kit` varchar(255) NOT NULL DEFAULT '',
  `enzyme` varchar(255) NOT NULL DEFAULT '',
  PRIMARY KEY  (`library_type_id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

--
-- Table structure for table `seq`
--

DROP TABLE IF EXISTS `seq`;
CREATE TABLE `seq` (
  `row_id` int unsigned NOT NULL AUTO_INCREMENT,
  `seq_id` mediumint(8) unsigned NOT NULL DEFAULT 0,
  `sample_id` int(10) NOT NULL DEFAULT '0',
  `library_id` int(10) NOT NULL DEFAULT '0',
  `accession_id` int(10) unsigned NOT NULL DEFAULT 0,
  `run_id` int(10) NOT NULL DEFAULT '0',
  `name` varchar(255) NOT NULL DEFAULT '',
  `hierarchy_name` varchar(255) NOT NULL DEFAULT '',
  `processed` int(10) DEFAULT 0,
  `tag1_id` varchar(40) DEFAULT NULL,
  `tag2_id` varchar(40) DEFAULT NULL,
  `lims_qc_status` enum('pending','pass','fail','-') DEFAULT 'pending',
  `auto_qc_status` enum('no_qc','passed','failed') DEFAULT 'no_qc',
  `qc_status` enum('no_qc','pending','passed','failed','investigate') DEFAULT 'no_qc',
  `withdrawn` tinyint(1) DEFAULT NULL,
  `manually_withdrawn` tinyint(1) DEFAULT NULL,
  `date` datetime DEFAULT NULL,
  `note_id` mediumint(8) unsigned DEFAULT NULL,
  `changed` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `current` tinyint(1) DEFAULT '0',
  PRIMARY KEY (`row_id`),
  KEY `seq_id` (`seq_id`),
  KEY `seqname` (`name`),
  KEY `library_id` (`library_id`),
  KEY `sample_id` (`sample_id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

--
-- Table structure for table `run`
--

DROP TABLE IF EXISTS `run`;
CREATE TABLE `run` (
  `row_id` int unsigned NOT NULL AUTO_INCREMENT,
  `run_id` mediumint(8) unsigned NOT NULL DEFAULT 0,
  `name` varchar(255) NOT NULL DEFAULT '',
  `hierarchy_name` varchar(255) NOT NULL DEFAULT '',
  `platform_id` int(10) NOT NULL DEFAULT '0',
  `centre_id` int(10) NOT NULL DEFAULT '0',
  `lims_id` int(10) NOT NULL DEFAULT '0',
  `element` tinyint(1) DEFAULT NULL,
  `changed` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `current` tinyint(1) DEFAULT '0',
  PRIMARY KEY (`row_id`),
  KEY `seq_id` (`seq_id`),
  KEY `runname` (`name`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

--
-- Table structure for table `centre`
--

DROP TABLE IF EXISTS `centre`;
CREATE TABLE `centre` (
  `centre_id` smallint(5) unsigned NOT NULL AUTO_INCREMENT,
  `name` varchar(255) NOT NULL DEFAULT '',
  `long_name` varchar(255) NOT NULL DEFAULT '',
  PRIMARY KEY  (`centre_id`),
  UNIQUE KEY `name` (`name`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

--
-- Table structure for table `platform`
--

DROP TABLE IF EXISTS `platform`;
CREATE TABLE `platform` (
  `platform_id` smallint(5) unsigned NOT NULL AUTO_INCREMENT,
  `name` varchar(255) NOT NULL DEFAULT '',
  `model` varchar(255) NOT NULL DEFAULT '',
  PRIMARY KEY  (`platform_id`),
  UNIQUE KEY `name` (`name`,`model`),
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

--
-- Table structure for table `accession`
--
DROP TABLE IF EXISTS `accession`;
CREATE TABLE `submission` (
  `accession_id` smallint(5) unsigned NOT NULL AUTO_INCREMENT,
  `name` varchar(255) NOT NULL DEFAULT '',
  `type` enum('project','seq','asm','sample','specimen') DEFAULT 'seq',
  `date` datetime NOT NULL DEFAULT '0000-00-00',
  `secondary` varchar(255) DEFAULT NULL,
  `title` varchar(255) DEFAULT NULL,
  `description` varchar(255) DEFAULT NULL,
  PRIMARY KEY  (`submission_id`),
  UNIQUE KEY `accession_id` (`accession_id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

--
-- Views
--

DROP VIEW if EXISTS `current_sample`;
CREATE VIEW current_sample AS SELECT * FROM sample WHERE current=true;
DROP VIEW if EXISTS `current_library`;
CREATE VIEW current_library AS SELECT * FROM library WHERE current=true;
DROP VIEW if EXISTS `current_run`;
CREATE VIEW current_run AS SELECT * FROM run WHERE current=true;
DROP VIEW if EXISTS `current_seq`;
CREATE VIEW current_seq AS SELECT * FROM seq WHERE current=true;
DROP VIEW if EXISTS `current_specimen`;
CREATE VIEW current_specimen AS SELECT * FROM specimen WHERE current=true;
DROP VIEW if EXISTS `current_species`;
CREATE VIEW current_species AS SELECT * FROM species WHERE current=true;
