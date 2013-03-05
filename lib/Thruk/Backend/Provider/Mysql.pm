package Thruk::Backend::Provider::Mysql;

use strict;
use warnings;
use Carp;
use Data::Dumper;
use Digest::MD5 qw/md5_hex/;
use DBI;
use Thruk::Utils;
use parent 'Thruk::Backend::Provider::Base';

=head1 NAME

Thruk::Backend::Provider::Mysql - connection provider for Mysql connections

=head1 DESCRIPTION

connection provider for Mysql connections

=head1 METHODS

##########################################################

=head2 new

create new manager

=cut
sub new {
    my( $class, $peer_config, $config ) = @_;

    die('need at least one peer. Minimal options are <options>peer = mysql://user:password@host:port/dbname</options>'."\ngot: ".Dumper($peer_config)) unless defined $peer_config->{'peer'};

    $peer_config->{'name'} = 'mysql' unless defined $peer_config->{'name'};
    if(!defined $peer_config->{'peer_key'}) {
        my $key = md5_hex($peer_config->{'name'}.$peer_config->{'peer'});
        $peer_config->{'peer_key'} = $key;
    }
    my($dbhost, $dbport, $dbuser, $dbpass, $dbname);
    if($peer_config->{'peer'} =~ m/^mysql:\/\/(.*?):(.*?)@(.*?):(\d+)\/(.*)$/mx) {
        $dbuser = $1;
        $dbpass = $2;
        $dbhost = $3;
        $dbport = $4;
        $dbname = $5;
    } else {
        die('Mysql connection must match this form: mysql://user:password@host:port/dbname');
    }

    my $self = {
        'dbhost'      => $dbhost,
        'dbport'      => $dbport,
        'dbname'      => $dbname,
        'dbuser'      => $dbuser,
        'dbpass'      => $dbpass,
        'config'      => $config,
        'peer_config' => $peer_config,
        'stash'       => undef,
        'verbose'     => 0,
    };
    bless $self, $class;

    return $self;
}

##########################################################

=head2 reconnect

recreate database connection

=cut
sub reconnect {
    my($self) = @_;
    if(defined $self->{'mysql'}) {
        $self->{'mysql'}->disconnect();
        delete $self->{'mysql'};
    }
    $self->_dbh();
    return;
}

##########################################################

=head2 _dbh

try to connect to database and return database handle

=cut
sub _dbh {
    my($self) = @_;
    if(!defined $self->{'mysql'}) {
        my $dsn = "DBI:mysql:database=".$self->{'dbname'}.";host=".$self->{'dbhost'}.";port=".$self->{'dbport'};
        $self->{'mysql'} = DBI->connect($dsn, $self->{'dbuser'}, $self->{'dbpass'}, {RaiseError => 1, AutoCommit => 0, mysql_enable_utf8 => 1});
    }
    return $self->{'mysql'};
}

##########################################################

=head2 peer_key

return the peers key

=cut
sub peer_key {
    my($self, $new_val) = @_;
    if(defined $new_val) {
        $self->{'peer_config'}->{'peer_key'} = $new_val;
    }
    return $self->{'peer_config'}->{'peer_key'};
}


##########################################################

=head2 peer_addr

return the peers address

=cut
sub peer_addr {
    my $self = shift;
    return $self->{'peer_config'}->{'peer'};
}

##########################################################

=head2 peer_name

return the peers name

=cut
sub peer_name {
    my $self = shift;
    return $self->{'peer_config'}->{'name'};
}

##########################################################

=head2 send_command

=cut
sub send_command {
    confess("not implemented");
    return;
}

##########################################################

=head2 get_processinfo

=cut
sub get_processinfo {
    confess("not implemented");
    return;
}

##########################################################

=head2 get_can_submit_commands

=cut
sub get_can_submit_commands {
    confess("not implemented");
    return;
}

##########################################################

=head2 get_contactgroups_by_contact

=cut
sub get_contactgroups_by_contact {
    confess("not implemented");
    return;
}

##########################################################

=head2 get_hosts

=cut
sub get_hosts {
    confess("not implemented");
    return;
}

##########################################################

=head2 get_hosts_by_servicequery

=cut
sub get_hosts_by_servicequery {
    confess("not implemented");
    return;
}

##########################################################

=head2 get_host_names

=cut
sub get_host_names{
    confess("not implemented");
    return;
}

##########################################################

=head2 get_hostgroups

=cut
sub get_hostgroups {
    confess("not implemented");
    return;
}

##########################################################

=head2 get_hostgroup_names

=cut
sub get_hostgroup_names {
    confess("not implemented");
    return;
}

##########################################################

=head2 get_services

=cut
sub get_services {
    confess("not implemented");
    return;
}

##########################################################

=head2 get_service_names

=cut
sub get_service_names {
    confess("not implemented");
    return;
}

##########################################################

=head2 get_servicegroups

=cut
sub get_servicegroups {
    confess("not implemented");
    return;
}

##########################################################

=head2 get_servicegroup_names

=cut
sub get_servicegroup_names {
    confess("not implemented");
    return;
}

##########################################################

=head2 get_comments

=cut
sub get_comments {
    confess("not implemented");
    return;
}

##########################################################

=head2 get_downtimes

=cut
sub get_downtimes {
    confess("not implemented");
    return;
}

##########################################################

=head2 get_contactgroups

=cut
sub get_contactgroups {
    confess("not implemented");
    return;
}

##########################################################

=head2 get_logs

  get_logs

returns logfile entries

=cut
sub get_logs {
    my($self, %options) = @_;

    my $orderby = '';
    if(defined $options{'sort'}->{'DESC'} and $options{'sort'}->{'DESC'} eq 'time') {
        $orderby = ' ORDER BY l.time DESC';
    }
    my($where,$contact,$system,$strict) = $self->_get_filter($options{'filter'});

    my $prefix = $options{'collection'};
    $prefix    =~ s/^logs_//gmx;

    my $dbh = $self->_dbh;
    my $sql = '
        SELECT
            l.time as time,
            l.class as class,
            l.type as type,
            l.state as state,
            l.state_type as state_type,
            IFNULL(h.host_name, "") as host_name,
            IFNULL(s.service_description, "") as service_description,
            p1.output as plugin_output,
            CONCAT("[", l.time,"] ",
                   IF(l.type IS NULL, "", IF(l.type != "", CONCAT(l.type, ": "), "")),
                   IF(h.host_name IS NULL, "", CONCAT(h.host_name, ";")),
                   IF(s.service_description IS NULL, "", CONCAT(s.service_description, ";")),
                   p2.output,
                   p1.output
                ) as message
        FROM
            '.$prefix.'_log l
            LEFT JOIN '.$prefix.'_host h ON l.host_id = h.host_id
            LEFT JOIN '.$prefix.'_service s ON l.service_id = s.service_id
            LEFT JOIN '.$prefix.'_plugin_output p1 ON l.plugin_output = p1.output_id
            LEFT JOIN '.$prefix.'_plugin_output p2 ON l.message = p2.output_id
        '.$where.'
        '.$orderby.'
    ';
    confess($sql) if $sql =~ m/(ARRAY|HASH)/mx;
    my $data = $dbh->selectall_arrayref($sql, { Slice => {} });
    # authorization
    if($contact) {
        my @new_data;
        my @hosts = @{$dbh->selectall_arrayref("SELECT h.host_name FROM ".$prefix."_host h, ".$prefix."_contact_host_rel chr, ".$prefix."_contact c WHERE h.host_id = chr.host_id AND c.contact_id = chr.contact_id AND c.name = ".$dbh->quote($contact))};
        my $hosts_lookup = {};
        for my $h (@hosts) { $hosts_lookup->{$h->[0]} = 1; }

        my $sql = "SELECT h.host_name, s.service_description
                   FROM
                     ".$prefix."_service s,
                     ".$prefix."_host h,
                     ".$prefix."_contact_host_rel chr,
                     ".$prefix."_contact c1,
                     ".$prefix."_contact_service_rel csr,
                     ".$prefix."_contact c2
                   WHERE
                     s.host_id = h.host_id
                     AND h.host_id = chr.host_id
                     AND c1.contact_id = chr.contact_id
                     AND c2.contact_id = csr.contact_id
                     AND s.service_id = csr.service_id
                     AND (c1.name = ".$dbh->quote($contact)."
                       OR c2.name = ".$dbh->quote($contact).")"
                   ;
        my $services        = $dbh->selectall_arrayref($sql);
        my $services_lookup = {};
        for my $s (@{$services}) { $services_lookup->{$s->[0]}->{$s->[1]} = 1; }
        for my $r (@{$data}) {
            if($r->{'service_description'}) {
                if($strict) {
                    if(!defined $services_lookup->{$r->{'host_name'}}->{$r->{'service_description'}}) {
                        next;
                    }
                } else {
                    if(!defined $hosts_lookup->{$r->{'host_name'}} and !defined $services_lookup->{$r->{'host_name'}}->{$r->{'service_description'}}) {
                        next;
                    }
                }
            }
            elsif($r->{'host_name'}) {
                if(!defined $hosts_lookup->{$r->{'host_name'}}) {
                    next;
                }
            }
            else {
                if(!$system) {
                    next;
                }
            }
            push @new_data, $r;
        }
        $data = \@new_data;
    }

    return($data, 'sorted');
}

##########################################################

=head2 get_timeperiods

=cut
sub get_timeperiods {
    confess("not implemented");
    return;
}

##########################################################

=head2 get_timeperiod_names

=cut
sub get_timeperiod_names {
    confess("not implemented");
    return;
}

##########################################################

=head2 get_commands

=cut
sub get_commands {
    confess("not implemented");
    return;
}

##########################################################

=head2 get_contacts

=cut
sub get_contacts {
    confess("not implemented");
    return;
}

##########################################################

=head2 get_contact_names

=cut
sub get_contact_names {
    confess("not implemented");
    return;
}

##########################################################

=head2 get_host_stats

=cut
sub get_host_stats {
    confess("not implemented");
    return;
}

##########################################################

=head2 get_service_stats

=cut
sub get_service_stats {
    confess("not implemented");
    return;
}

##########################################################

=head2 get_performance_stats

=cut
sub get_performance_stats {
    confess("not implemented");
    return;
}

##########################################################

=head2 get_extra_perf_stats

=cut
sub get_extra_perf_stats {
    confess("not implemented");
    return;
}

##########################################################

=head2 set_verbose

  set_verbose

sets verbose mode for this backend and returns old value

=cut
sub set_verbose {
    my($self, $val) = @_;
    my $old = $self->{'verbose'};
    $self->{'verbose'} = $val;
    return($old);
}

##########################################################

=head2 set_stash

  set_stash

make stash accessible for the backend

=cut
sub set_stash {
    my($self, $stash) = @_;
    $self->{'stash'} = $stash;
    return;
}

##########################################################

=head2 renew_logcache

  renew_logcache

renew logcache

=cut
sub renew_logcache {
    return;
}

##########################################################

=head2 _add_peer_data

  _add_peer_data

add peer name, addr and key to result array

=cut
sub _add_peer_data {
    my($self, $data) = @_;
    for my $d (@{$data}) {
        $d->{'peer_name'} = $self->peer_name;
        $d->{'peer_addr'} = $self->peer_addr;
        $d->{'peer_key'}  = $self->peer_key;
    }
    return $data;
}

##########################################################

=head2 _get_filter

  _get_filter

return Mysql filter

=cut
sub _get_filter {
    my($self, $inp) = @_;
    my $filter = $self->_get_subfilter($inp);
    if($filter and ref $filter) {
        $filter = '('.join(' AND ', @{$filter}).')';
    }
    $filter = " WHERE ".$filter if $filter;

    # message filter have to go into a having clause
    my($contact,$system,$strict);
    if($filter and $filter =~ m/message\ (RLIKE|=|LIKE|!=)\ /mx) {
        if($filter =~ s/^\ WHERE\ \((time\ >=\ \d+\ AND\ time\ <=\ \d+)//mx) {
            my $timef = $1;
            my $having = $filter;
            $filter = 'WHERE ('.$timef.')';
            # time filter are the only filter
            if($having eq ')') {
                $having = '';
            } else {
                $having =~ s/^\ AND\ //mx;
                $having =~ s/\)$//mx;
                $filter = $filter.' HAVING ('.$having.')';
            }
        }
    }

    # authentication filter hack
    # hosts, services and system_information
    # ((current_service_contacts IN ('test_contact') AND service_description != '') OR current_host_contacts IN ('test_contact') OR (service_description = '' AND host_name = ''))
    if($filter =~ s/\(\(current_service_contacts\ IN\ \('(.*?)'\)\ AND\ service_description\ !=\ ''\)\ OR\ current_host_contacts\ IN\ \('(.*?)'\)\ OR\ \(service_description\ =\ ''\ AND\ host_name\ =\ ''\)\)//mx) {
        $contact = $1;
        $system  = 1;
    }
    # hosts, services and system_information and strict host auth on
    if($filter =~ s/\(\(current_service_contacts\ IN\ \('(.*?)'\)\ AND\ service_description\ !=\ ''\)\ OR\ \(current_host_contacts\ IN\ \('(.*?)'\)\ AND\ service_description\ =\ ''\)\ OR\ \(service_description\ =\ ''\ AND\ host_name\ =\ ''\)\)//mx) {
        $contact = $1;
        $system  = 1;
        $strict  = 1;
    }
    # hosts and services and strict host auth on
    if($filter =~ s/\(\(current_service_contacts\ IN\ \('test_contact'\)\ AND\ service_description\ !=\ ''\)\ OR\ \(current_host_contacts\ IN\ \('test_contact'\)\ AND\ service_description\ =\ ''\)\)//mx) {
        $contact = $1;
        $strict  = 1;
    }
    # hosts and services
    # ((current_service_contacts IN ('test_contact') AND service_description != '') OR current_host_contacts IN ('test_contact'))
    if($filter =~ s/\(\(current_service_contacts\ IN\ \('(.*?)'\)\ AND\ service_description\ !=\ ''\)\ OR\ current_host_contacts\ IN\ \('.*?'\)\)//mx) {
        $contact = $1;
    }

    $filter =~ s/\ AND\ \)/)/gmx;
    $filter = '' if $filter eq ' WHERE ';

    return($filter, $contact, $system, $strict);
}

##########################################################

=head2 _get_subfilter

  _get_subfilter

return Mysql filter

=cut
sub _get_subfilter {
    my($self, $inp, $f) = @_;
    return '' unless defined $inp;
    if(ref $inp eq 'ARRAY') {
        # empty lists
        return '' if scalar @{$inp} == 0;

        # single array items will be stripped from array
        if(scalar @{$inp} == 1) {
            return $self->_get_subfilter($inp->[0]);
        }

        my $x   = 0;
        my $num = scalar @{$inp};
        my $filter = [];
        while($x < $num) {
            # [ 'key', { 'op' => 'value' } ]
            if(exists $inp->[$x+1] and ref $inp->[$x] eq '' and ref $inp->[$x+1] eq 'HASH') {
                my $key = $inp->[$x];
                my $val = $inp->[$x+1];
                push @{$filter}, $self->_get_subfilter({$key => $val});
                $x=$x+2;
                next;
            }
            # [ '-or', [ 'key' => 'value' ] ]
            if(exists $inp->[$x+1] and ref $inp->[$x] eq '' and ref $inp->[$x+1] eq 'ARRAY') {
                my $key = $inp->[$x];
                my $val = $inp->[$x+1];
                push @{$filter}, $self->_get_subfilter({$key => $val});
                $x=$x+2;
                next;
            }

            # [ 'key', 'value' ] => { 'key' => 'value' }
            if(exists $inp->[$x+1] and ref $inp->[$x] eq '' and ref $inp->[$x+1] eq '') {
                my $key = $inp->[$x];
                my $val = $inp->[$x+1];
                push @{$filter}, $self->_get_subfilter({$key => $val});
                $x=$x+2;
                next;
            }

            if(defined $inp->[$x]) {
                my $f =  $self->_get_subfilter($inp->[$x]);
                if($f and ref $f) {
                    $f= '('.join(' AND ', @{$f}).')';
                }
                push @{$filter}, $f;
            }
            $x++;
        }
        if(scalar @{$filter} == 1) {
            return $filter->[0];
        }
        return $filter;
    }
    if(ref $inp eq 'HASH') {
        # single hash elements with an operator
        if(scalar keys %{$inp} == 1) {
            my $k = [keys   %{$inp}]->[0];
            my $v = [values %{$inp}]->[0];
            if($k eq '=')                           { return '= '._quote($v); }
            if($k eq '!=')                          { return '!= '._quote($v); }
            if($k eq '~')                           { return 'RLIKE '._quote($v); }
            if($k eq '~~')                          { return 'RLIKE '._quote($v); }
            if($k eq '!~~')                         { return 'NOT RLIKE '._quote($v); }
            if($k eq '>='  and ref $v eq 'ARRAY')   { confess("whuus") unless defined $f; return '= '.join(' OR '.$f.' = ', @{_quote($v)}); }
            if($k eq '!>=' and ref $v eq 'ARRAY')   { confess("whuus") unless defined $f; return '!= '.join(' OR '.$f.' != ', @{_quote($v)}); }
            if($k eq '!>=')                         { return '!= '._quote($v); }
            if($k eq '>=' and $v !~ m/^[\d\.]+$/mx) { return 'IN ('._quote($v).')'; }
            if($k eq '>=')                          { return '>= '._quote($v); }
            if($k eq '<=')                          { return '<= '._quote($v); }
            if($k eq '-or') {
                my $list = $self->_get_subfilter($v);
                if(ref $list) {
                    for my $l (@{$list}) {
                        if(ref $l eq 'ARRAY') {
                            $l = '('.join(' AND ', @{$l}).')';
                        }
                    }
                    return('('.join(' OR ', @{$list}).')');
                }
                return $list;
            }
            if($k eq '-and') {
                my $list = $self->_get_subfilter($v);
                if(ref $list) {
                    for my $l (@{$list}) {
                        if(ref $l eq 'ARRAY') {
                            $l = '('.join(' AND ', @{$l}).')';
                        }
                    }
                    return('('.join(' AND ', @{$list}).')');
                }
                return $list;
            }
            if(ref $v) {
                $v = $self->_get_subfilter($v, $k);
                if($v =~ m/\ OR\ $k\ /mx) {
                    return '('.$k.' '.$v.')';
                }
                return $k.' '.$v;
            }
            return $k.' = '._quote($v);
        }

        # multiple keys will be converted to list
        # { 'key' => 'v', 'key2' => v }
        my $list = [];
        for my $k (keys %{$inp}) {
            push @{$list}, {$k => $inp->{$k}};
        }
        return $self->_get_subfilter({'-and' => $list});
    }
    return $inp;
}

##########################################################
sub _quote {
    return "''" unless defined $_[0];
    if(ref $_[0] eq 'ARRAY') {
        my $list = [];
        for my $v (@{$_[0]}) {
            push @{$list}, _quote($v);
        }
        return $list;
    }
    if($_[0] =~ m/^[\d\.]+$/mx) {
        return $_[0];
    }
    $_[0] =~ s/'/\'/gmx;
    return("'".$_[0]."'");
}

##########################################################

=head2 _get_logs_start_end

  _get_logs_start_end

returns the min/max timestamp for given logs

=cut
sub _get_logs_start_end {
    my($self, %options) = @_;
    my($start, $end);
    my $prefix = $options{'collection'} || $self->{'peer_config'}->{'peer_key'};
    $prefix    =~ s/^logs_//gmx;
    my $dbh  = $self->_dbh();
    my @data = @{$dbh->selectall_arrayref('SELECT MIN(time) as mi, MAX(time) as ma FROM '.$prefix.'_log LIMIT 1', { Slice => {} })};
    $start   = $data[0]->{'mi'} if defined $data[0];
    $end     = $data[0]->{'ma'} if defined $data[0];
    return([$start, $end]);
}

##########################################################

=head2 _log_stats

  _log_stats

gather log statistics

=cut

sub _log_stats {
    my($self, $c) = @_;

    $c->stats->profile(begin => "Mysql::_log_stats");

    Thruk::Action::AddDefaults::_set_possible_backends($c, {}) unless defined $c->stash->{'backends'};
    my $output = sprintf("%-20s %-15s %-13s %7s\n", 'Backend', 'Index Size', 'Data Size', 'Items');
    my @result;
    for my $key (@{$c->stash->{'backends'}}) {
        my $peer = $c->{'db'}->get_peer_by_key($key);
        my $dbh  = $peer->{'logcache'}->_dbh();
        my $res  = $dbh->selectall_hashref("SHOW TABLE STATUS LIKE '".$key."%'", 'Name');
        next unless defined $res->{$key.'_log'};
        my $index_size = $res->{$key.'_log'}->{'Index_length'} + $res->{$key.'_plugin_output'}->{'Index_length'};
        my $data_size  = $res->{$key.'_log'}->{'Data_length'}  + $res->{$key.'_plugin_output'}->{'Data_length'};
        my($val1,$unit1) = Thruk::Utils::reduce_number($index_size, 'B', 1024);
        my($val2,$unit2) = Thruk::Utils::reduce_number($data_size, 'B', 1024);
        $output .= sprintf("%-20s %5.1f %-9s %5.1f %-7s %7d\n", $c->stash->{'backend_detail'}->{$key}->{'name'}, $val1, $unit1, $val2, $unit2, $res->{$key.'_log'}->{'Rows'});
        push @result, {
            key   => $key,
            name  => $c->stash->{'backend_detail'}->{$key}->{'name'},
            index => $val1.' '.$unit1,
            size  => $val2.' '.$unit2,
        };
    }

    $c->stats->profile(end => "Mysql::_log_stats");
    return @result if wantarray;
    return $output;
}

##########################################################

=head2 _import_logs

  _import_logs

imports logs into Mysql

=cut

sub _import_logs {
    my($self, $c, $mode, $verbose, $backends, $blocksize) = @_;

    $c->stats->profile(begin => "Mysql::_import_logs($mode)");

    my $backend_count = 0;
    my $log_count     = 0;
    my $log_skipped   = 0;

    if(!defined $backends) {
        Thruk::Action::AddDefaults::_set_possible_backends($c, {}) unless defined $c->stash->{'backends'};
        $backends = $c->stash->{'backends'};
    }
    $backends = Thruk::Utils::list($backends);

    for my $key (@{$backends}) {
        my $prefix = $key;
        my $peer   = $c->{'db'}->get_peer_by_key($key);
        next unless $peer->{'enabled'};
        $c->stats->profile(begin => "$key");
        $backend_count++;
        $peer->{'logcache'}->reconnect();
        my $dbh = $peer->{'logcache'}->_dbh;

        print "running ".$mode." for site ".$c->stash->{'backend_detail'}->{$key}->{'name'},"\n" if $verbose;

        # backends maybe down, we still want to continue updates
        eval {
            if($mode eq 'update' or $mode eq 'import' or $mode eq 'clean') {
                $log_count += $self->_update_logcache($c, $mode, $peer, $dbh, $prefix, $verbose, $blocksize);
            }
            elsif($mode eq 'authupdate') {
                $log_count += $self->_update_logcache_auth($c, $peer, $dbh, $prefix, $verbose);
            }
        };
        print "ERROR: ", $@,"\n" if $@ and $verbose;

        $c->stats->profile(end => "$key");
        print "\n" if $verbose;
    }

    $c->stats->profile(end => "Mysql::_import_logs($mode)");
    return($backend_count, $log_count);
}

##########################################################
sub _update_logcache {
    my($self, $c, $mode, $peer, $dbh, $prefix, $verbose, $blocksize) = @_;

    unless(defined $blocksize) {
        $blocksize = 86400;
        $blocksize = 365 if $mode eq 'clean';
    }

    my $log_count = 0;

    if($mode eq 'import') {
        for my $stm (@{_get_create_statements($prefix)}) {
            $dbh->do($stm);
        }
    }

    if($mode eq 'clean') {
        my $start = time() - ($blocksize * 86400);
        print "cleaning logs older than:  ", scalar localtime $start, "\n" if $verbose;
        $log_count += $dbh->do("DELETE FROM ".$prefix."_log WHERE time < ".$start);
        return $log_count;
    }


    my $host_lookup    = {};
    my $service_lookup = {};
    my $plugin_lookup  = {};
    if($mode eq 'import') {
        $host_lookup    = _get_host_lookup($dbh,$peer,$prefix);
        $service_lookup = _get_service_lookup($dbh,$peer,$prefix,$host_lookup);
    }

    # get start / end timestamp
    my($mstart, $mend);
    my($start, $end);
    my $filter = [];
    if($mode eq 'update') {
        $c->stats->profile(begin => "get last mysql timestamp");
        # get last timestamp from Mysql
        ($mstart, $mend) = @{$peer->{'logcache'}->_get_logs_start_end(prefix => $prefix)};
        if(defined $mend) {
            print "latest entry in logcache: ", scalar localtime $mend, "\n" if $verbose;
            push @{$filter}, {time => { '>=' => $mend }};
        }
        $c->stats->profile(end => "get last mysql timestamp");
    }
    $c->stats->profile(begin => "get livestatus timestamp");
    ($start, $end) = @{$peer->{'class'}->_get_logs_start_end(filter => $filter)};
    print "latest entry in logfile:  ", scalar localtime $end, "\n" if $verbose;
    $c->stats->profile(end => "get livestatus timestamp");
    print "importing ", scalar localtime $start, " till ", scalar localtime $end, "\n" if $verbose;
    my $time = $start;

    while($time <= $end) {
        my $stime = scalar localtime $time;
        $c->stats->profile(begin => $stime);
        my $lookup = {};
        print scalar localtime $time if $verbose;
        my $logs = [];
        eval {
            ($logs) = $peer->{'class'}->get_logs(nocache => 1,
                                                   filter  => [{ '-and' => [
                                                                            { time => { '>=' => $time } },
                                                                            { time => { '<'  => $time + $blocksize } }
                                                              ]}],
                                                   columns => [qw/
                                                                class time type state host_name service_description plugin_output message state_type
                                                             /],
                                                  );
            if($mode eq 'update') {
                # get already stored logs to filter duplicates
                my($mlogs) = $peer->{'class'}->get_logs(
                                                    filter  => [{ '-and' => [
                                                                            { time => { '>=' => $time } },
                                                                            { time => { '<=' => $time + $blocksize } }
                                                               ]}]
                                          );
                for my $l (@{$mlogs}) {
                    $lookup->{$l->{'message'}} = 1;
                }
            }
        };
        if($@) {
            my $err = $@;
            chomp($err);
            print $err;
        }

        $time = $time + $blocksize;
        my $stm = "INSERT INTO ".$prefix."_log (time,class,type,state,state_type,host_id,service_id,plugin_output,message) VALUES";
        my @values;
        for my $l (@{$logs}) {
            if($mode eq 'update') {
                next if defined $lookup->{$l->{'message'}};
            }
            if($l->{'type'} eq 'TIMEPERIOD TRANSITION') {
                $l->{'plugin_output'} = '';
            }
            $log_count++;
            print '.' if $log_count%100 == 0 and $verbose;
            my $type    = $l->{'type'};
            $type = 'TIMEPERIOD TRANSITION' if $type =~ m/TIMEPERIOD\ TRANSITION/mx;
            my $state   = $l->{'state'};
            if($state eq '') { $state = 'NULL'; }
            my $state_type = $l->{'state_type'};
            if($state_type eq '') { $state_type = 'NULL'; }
            my $host    = _host_lookup($host_lookup, $l->{'host_name'}, $dbh, $prefix);
            my $svc     = _service_lookup($service_lookup, $host_lookup, $l->{'host_name'}, $l->{'service_description'}, $dbh, $prefix);
            _trim_log_entry($l);
            my $plugin  = _plugin_lookup($plugin_lookup, $l->{'plugin_output'}, $dbh, $prefix);
            my $message = _plugin_lookup($plugin_lookup, $l->{'message'}, $dbh, $prefix);
            push @values, '('.$l->{'time'}.','.$l->{'class'}.','.$dbh->quote($type).','.$state.','.$dbh->quote($state_type).','.$host.','.$svc.','.$plugin.','.$message.')'
        }
        $dbh->do($stm.join(',', @values)) if scalar @values > 0;
        $dbh->commit; # commit every block
        $c->stats->profile(end => $stime);
        print "\n" if $verbose;
    }

    if($mode eq 'import') {
        print "updateing auth cache\n" if $verbose;
        $self->_update_logcache_auth($c, $peer, $dbh, $prefix, $verbose);
    }

    return $log_count;
}


##########################################################
sub _update_logcache_auth {
    my($self, $c, $peer, $dbh, $prefix, $verbose) = @_;

    $dbh->do("TRUNCATE TABLE ".$prefix."_contact");
    my $contact_lookup = _get_contact_lookup($dbh,$peer,$prefix);
    my $host_lookup    = _get_host_lookup($dbh,$peer,$prefix);
    my $service_lookup = _get_service_lookup($dbh,$peer,$prefix);

    # update hosts
    my($hosts)    = $peer->{'class'}->get_hosts(columns => [qw/name contacts/]);
    print "hosts" if $verbose;
    my $stm = "INSERT INTO ".$prefix."_contact_host_rel (contact_id, host_id) VALUES";
    $dbh->do("TRUNCATE TABLE ".$prefix."_contact_host_rel");
    for my $host (@{$hosts}) {
        my $host_id    = _host_lookup($host_lookup, $host->{'name'}, $dbh, $prefix);
        my @values;
        for my $contact (@{$host->{'contacts'}}) {
            my $contact_id = _contact_lookup($contact_lookup, $contact, $dbh, $prefix);
            push @values, '('.$contact_id.','.$host_id.')'
        }
        $dbh->do($stm.join(',', @values)) if scalar @values > 0;
        print "." if $verbose;
    }
    print "\n" if $verbose;

    # update services
    print "services" if $verbose;
    $dbh->do("TRUNCATE TABLE ".$prefix."_contact_service_rel");
    $stm = "INSERT INTO ".$prefix."_contact_service_rel (contact_id, service_id) VALUES";
    my($services) = $peer->{'class'}->get_services(columns => [qw/host_name description contacts/]);
    for my $service (@{$services}) {
        my $service_id = _service_lookup($service_lookup, $host_lookup, $service->{'host_name'}, $service->{'description'}, $dbh, $prefix);
        my @values;
        for my $contact (@{$service->{'contacts'}}) {
            my $contact_id = _contact_lookup($contact_lookup, $contact, $dbh, $prefix);
            push @values, '('.$contact_id.','.$service_id.')'
        }
        $dbh->do($stm.join(',', @values)) if scalar @values > 0;
        print "." if $verbose;
    }

    $dbh->commit;
    print "\n" if $verbose;

    return(scalar @{$hosts} + scalar @{$services});
}

##########################################################
sub _get_host_lookup {
    my($dbh,$peer,$prefix) = @_;

    my $sth = $dbh->prepare("SELECT host_id, host_name FROM ".$prefix."_host");
    $sth->execute;
    my $hosts_lookup = {};
    for my $r (@{$sth->fetchall_arrayref()}) { $hosts_lookup->{$r->[1]} = $r->[0]; }

    my($hosts) = $peer->{'class'}->get_hosts(columns => [qw/name/]);
    my $stm = "INSERT INTO ".$prefix."_host (host_name) VALUES";
    my @values;
    for my $h (@{$hosts}) {
        next if defined $hosts_lookup->{$h->{'name'}};
        push @values, '('.$dbh->quote($h->{'name'}).')';
    }
    if(scalar @values > 0) {
        $dbh->do($stm.join(',', @values));
        $dbh->commit;
        $sth->execute;
        for my $r (@{$sth->fetchall_arrayref()}) { $hosts_lookup->{$r->[1]} = $r->[0]; }
    }
    return $hosts_lookup;
}


##########################################################
sub _get_service_lookup {
    my($dbh,$peer,$prefix,$hosts_lookup) = @_;

    my $sth = $dbh->prepare("SELECT s.service_id, h.host_name, s.service_description FROM ".$prefix."_service s, ".$prefix."_host h WHERE s.host_id = h.host_id");
    $sth->execute;
    my $services_lookup = {};
    for my $r (@{$sth->fetchall_arrayref()}) { $services_lookup->{$r->[1]}->{$r->[2]} = $r->[0]; }

    my($services) = $peer->{'class'}->get_services(columns => [qw/host_name description/]);
    my $stm = "INSERT INTO ".$prefix."_service (host_id, service_description) VALUES";
    my @values;
    for my $s (@{$services}) {
        next if defined $services_lookup->{$s->{'host_name'}}->{$s->{'description'}};
        my $host_id = $hosts_lookup->{$s->{'host_name'}};
        if(!defined $host_id) {
            warn("got no id for host: ".$s->{'host_name'});
        } else {
            push @values, '('.$host_id.','.$dbh->quote($s->{'service_description'}).')';
        }
    }
    if(scalar @values > 0) {
        $dbh->do($stm.join(',', @values));
        $dbh->commit;
        $sth->execute;
        for my $r (@{$sth->fetchall_arrayref()}) { $services_lookup->{$r->[1]}->{$r->[2]} = $r->[0]; }
    }
    return $services_lookup;
}

##########################################################
sub _get_contact_lookup {
    my($dbh,$peer,$prefix) = @_;

    my $sth = $dbh->prepare("SELECT contact_id, name FROM ".$prefix."_contact");
    $sth->execute;
    my $contact_lookup = {};
    for my $r (@{$sth->fetchall_arrayref()}) { $contact_lookup->{$r->[1]} = $r->[0]; }

    my($contacts) = $peer->{'class'}->get_contacts(columns => [qw/name/]);
    my $stm = "INSERT INTO ".$prefix."_contact (name) VALUES";
    my @values;
    for my $c (@{$contacts}) {
        next if defined $contact_lookup->{$c->{'name'}};
        push @values, '('.$dbh->quote($c->{'name'}).')';
    }
    if(scalar @values > 0) {
        $dbh->do($stm.join(',', @values));
        $dbh->commit;
        $sth->execute;
        for my $r (@{$sth->fetchall_arrayref()}) { $contact_lookup->{$r->[1]} = $r->[0]; }
    }
    return $contact_lookup;
}

##########################################################
sub _plugin_lookup {
    my($hash, $look, $dbh, $prefix) = @_;
    my $id = $hash->{$look};
    return $id if $id;

    # check database first
    my @ids = @{$dbh->selectall_arrayref('SELECT output_id FROM '.$prefix.'_plugin_output WHERE output = '.$dbh->quote($look).' LIMIT 1')};
    if(scalar @ids > 0) {
        $id = $ids[0]->[0];
        $hash->{$look} = $id;
        return $id;
    }

    $dbh->do("INSERT INTO ".$prefix."_plugin_output (output) VALUES(".$dbh->quote($look).")");
    $id = $dbh->last_insert_id(undef, undef, undef, undef);
    $hash->{$look} = $id;
    return $id;
}

##########################################################
sub _host_lookup {
    my($host_lookup, $host_name, $dbh, $prefix) = @_;
    return 'NULL' unless $host_name;

    my $id = $host_lookup->{$host_name};
    return $id if $id;

    # check database first
    my @ids = @{$dbh->selectall_arrayref('SELECT host_id FROM '.$prefix.'_host WHERE host_name = '.$dbh->quote($host_name).' LIMIT 1')};
    if(scalar @ids > 0) {
        $id = $ids[0]->[0];
        $host_lookup->{$host_name} = $id;
        return $id;
    }

    $dbh->do("INSERT INTO ".$prefix."_host (host_name) VALUES(".$dbh->quote($host_name).")");
    $id = $dbh->last_insert_id(undef, undef, undef, undef);
    $host_lookup->{$host_name} = $id;

    return $id;
}

##########################################################
sub _service_lookup {
    my($service_lookup, $host_lookup, $host_name, $service_description, $dbh, $prefix) = @_;
    return 'NULL' unless $service_description;

    my $id = $service_lookup->{$host_name}->{$service_description};
    return $id if $id;

    my $host_id = _host_lookup($host_lookup, $host_name, $dbh, $prefix);

    # check database first
    my @ids = @{$dbh->selectall_arrayref('SELECT service_id FROM '.$prefix.'_service WHERE host_id = '.$host_id.' AND service_description = '.$dbh->quote($service_description).' LIMIT 1')};
    if(scalar @ids > 0) {
        $id = $ids[0]->[0];
        $service_lookup->{$host_name}->{$service_description} = $id;
        return $id;
    }

    $dbh->do("INSERT INTO ".$prefix."_service (host_id, service_description) VALUES(".$host_id.", ".$dbh->quote($service_description).")");
    $id = $dbh->last_insert_id(undef, undef, undef, undef);
    $service_lookup->{$host_name}->{$service_description} = $id;

    return $id;
}

##########################################################
sub _contact_lookup {
    my($contact_lookup, $contact_name, $dbh, $prefix) = @_;
    return 'NULL' unless $contact_name;

    my $id = $contact_lookup->{$contact_name};
    return $id if $id;

    # check database first
    my @ids = @{$dbh->selectall_arrayref('SELECT contact_id FROM '.$prefix.'_contact WHERE name = '.$dbh->quote($contact_name).' LIMIT 1')};
    if(scalar @ids > 0) {
        $id = $ids[0]->[0];
        $contact_lookup->{$contact_name} = $id;
        return $id;
    }

    $dbh->do("INSERT INTO ".$prefix."_contact (name) VALUES(".$dbh->quote($contact_name).")");
    $id = $dbh->last_insert_id(undef, undef, undef, undef);
    $contact_lookup->{$contact_name} = $id;

    return $id;
}

##########################################################
sub _trim_log_entry {
    my($l) = @_;
    # strip time
    $l->{'message'} =~ s/^\[$l->{'time'}\]\ //mx;

    # strip type
    $l->{'message'} =~ s/^\Q$l->{'type'}\E:\ //mx;

    # strip host_name
    if($l->{'host_name'}) {
        $l->{'message'} =~ s/^\Q$l->{'host_name'}\E;//mx;
    }

    # strip service description
    if($l->{'service_description'}) {
        $l->{'message'} =~ s/^\Q$l->{'service_description'}\E;//mx;
    }

    # strip plugin output from the end
    if($l->{'plugin_output'}) {
        $l->{'message'} =~ s/\Q$l->{'plugin_output'}\E$//mx;
    }
    return;
}

##########################################################
sub _get_create_statements {
    my($prefix) = @_;
    my @statements = (
        "DROP TABLE IF EXISTS ".$prefix."_contact",
        "CREATE TABLE ".$prefix."_contact (
          contact_id mediumint(8) unsigned NOT NULL AUTO_INCREMENT,
          name varchar(150) COLLATE utf8_unicode_ci NOT NULL,
          PRIMARY KEY (contact_id)
        ) ENGINE=MyISAM DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci",

        "DROP TABLE IF EXISTS ".$prefix."_contact_host_rel",
        "CREATE TABLE ".$prefix."_contact_host_rel (
          contact_id mediumint(8) unsigned NOT NULL,
          host_id mediumint(8) unsigned NOT NULL,
          PRIMARY KEY (contact_id,host_id)
        ) ENGINE=MyISAM DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci",

        "DROP TABLE IF EXISTS ".$prefix."_contact_service_rel",
        "CREATE TABLE ".$prefix."_contact_service_rel (
          contact_id mediumint(8) unsigned NOT NULL,
          service_id mediumint(8) unsigned NOT NULL,
          PRIMARY KEY (contact_id,service_id)
        ) ENGINE=MyISAM DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci",

        "DROP TABLE IF EXISTS ".$prefix."_host",
        "CREATE TABLE ".$prefix."_host (
          host_id mediumint(8) unsigned NOT NULL AUTO_INCREMENT,
          host_name varchar(150) COLLATE utf8_unicode_ci NOT NULL,
          PRIMARY KEY (host_id)
        ) ENGINE=MyISAM DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci",

        "DROP TABLE IF EXISTS ".$prefix."_log",

        "CREATE TABLE IF NOT EXISTS ".$prefix."_log (
          time int(11) unsigned NOT NULL,
          class tinyint(3) unsigned NOT NULL,
          type enum('CURRENT SERVICE STATE','CURRENT HOST STATE','SERVICE NOTIFICATION','HOST NOTIFICATION','SERVICE ALERT','HOST ALERT','SERVICE EVENT HANDLER','HOST EVENT HANDLER','EXTERNAL COMMAND','PASSIVE SERVICE CHECK','PASSIVE HOST CHECK','SERVICE FLAPPING ALERT','HOST FLAPPING ALERT','SERVICE DOWNTIME ALERT','HOST DOWNTIME ALERT','LOG ROTATION','INITIAL HOST STATE','INITIAL SERVICE STATE','TIMEPERIOD TRANSITION') COLLATE utf8_unicode_ci DEFAULT NULL,
          state tinyint(2) unsigned DEFAULT NULL,
          state_type enum('HARD','SOFT') COLLATE utf8_unicode_ci NOT NULL,
          host_id mediumint(8) unsigned DEFAULT NULL,
          service_id mediumint(8) unsigned DEFAULT NULL,
          plugin_output mediumint(8) NOT NULL,
          message mediumint(8) NOT NULL,
          KEY time (time)
        ) ENGINE=MyISAM DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci",

        "DROP TABLE IF EXISTS ".$prefix."_plugin_output",
        "CREATE TABLE ".$prefix."_plugin_output (
          output_id mediumint(8) unsigned NOT NULL AUTO_INCREMENT,
          output text NOT NULL,
          PRIMARY KEY (output_id)
        ) ENGINE=MyISAM DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci",

        "DROP TABLE IF EXISTS ".$prefix."_service",
        "CREATE TABLE ".$prefix."_service (
          service_id mediumint(8) unsigned NOT NULL AUTO_INCREMENT,
          host_id mediumint(8) unsigned NOT NULL,
          service_description varchar(150) COLLATE utf8_unicode_ci NOT NULL,
          PRIMARY KEY (service_id)
        ) ENGINE=MyISAM DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci",
    );
    return \@statements;
}

##########################################################

=head1 AUTHOR

Sven Nierlein, 2013, <sven.nierlein@consol.de>

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;