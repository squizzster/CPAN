#!/usr/local/bin/perl
use strict;
use Data::Dumper;
my $command      = @ARGV;
my @command_list = @ARGV;

die 'The directory /gbooking/g-booking-server/cpan must exist' if (not -e '/gbooking/g-booking-server/cpan');

## START ##
  dbmopen(my %CPAN,'/gbooking/g-booking-server/cpan/CPAN.dat',0666);
    init() if virgin();
    help() if not $command;
    command(@command_list);
  dbmclose(%CPAN);
## END ##

sub command {
  return add(@command_list) if $command_list[0] eq 'add';
  return list()             if $command_list[0] eq 'list';
  die "Dunno?";
}

sub list {
  foreach my $key (sort keys %CPAN) {
    print "=> $key     ["  . $CPAN{$key}  . "]\n"  if $key ne '_virgin' and not $key=~m/__/;
  }
}


sub add_module {
  my $module = $_[0];
  $module=~s/ //g;
  my $version;
  my $check_version =  "/usr/local/bin/check-module-version --naked-res --format=json $module";
  my $version       =  `$check_version`;
  if ( $version=~m/\"latest_version\":\"(.*?)\"/ ) {
    $version = $1;
  }
  else {
    print "Cannot get the version for module [$module]\n";
    return;
  }

  if ( $CPAN{"$module\__v$version"} ) {
    ## Already exists... for now say that and return an error
    print "Module already exists v[$version], returning for now.\n";
    return;
  }
  if ( $CPAN{"$module"} ) {
    print "NEW VERSION [$version] for module [$module].\n";
  }

  run ('/usr/bin/rm -rf /gbooking/local_tmp/usr 2>/dev/null');
  mkdir '/gbooking'; mkdir '/gbooking/local_tmp'; mkdir '/gbooking/local_tmp/usr'; mkdir '/gbooking/local_tmp/usr/local';
  die 'Directory failure' if not -e '/gbooking/local_tmp/usr/local';
  chdir "/gbooking/local_tmp/";
  my $ok;
  $ok = run ("/usr/local/bin/cpm install --with-recommends -L /gbooking/local_tmp/usr/local $module");
  if (not $ok) {
    print "Could not install module [$module].\n";
    return;
  }
  # get version ... or try ?

  my $find_wc = "find /gbooking/local_tmp/usr/local 2>/dev/null | wc -l";
  my $find_no = `$find_wc`;
  chomp $find_no;

  if ( $find_no > 0 ) {
    print "[$module] requires [$find_no] files to execute.\n";
  }
  else {
    print "Could not find any files for [$module]. Ignored.\n";
    return;
  }

  ### tar up the complete list of files we found regardless... anything accessed we grab!
  chdir "/gbooking/local_tmp/";
  run ("tar -czf '/gbooking/g-booking-server/cpan/modules/$module\__v$version.tar.gz' ./ 2>/dev/null");
  print "ADDED [$module] with version [$version].\n";
  $CPAN{"$module\__v$version"}  = $version;
  $CPAN{$module}               = $find_no;
  run ('/usr/bin/rm -rf /gbooking/local_tmp/usr 2>/dev/null');
  return 1;
}


sub init {
  #
  mkdir "/gbooking/g-booking-server/cpan";
  mkdir "/gbooking/g-booking-server/cpan/modules";
  chdir "/";
  run('curl -s -L https://github.com/squizzster/ginstall/raw/master/cpm.tar.gz   | tar zxf - 2>/dev/null') or die "I could not install the CPM required files.\n";
  run('curl -s -L https://github.com/squizzster/ginstall/raw/master/cpanm.tar.gz | tar zxf - 2>/dev/null') or die "I could not install the CPANM required files.\n";
  #
  # We are good to go!
  $CPAN{_virgin} = 1;
}

sub run {
  my $cmd = $_[0];
  my $ok  = system($cmd) if $cmd;
  return 1 if not $ok;
  return;
}

sub add {
  my @what = @_;
  shift @what;
  foreach my $module (@what) {
    add_module($module);
  }
}

sub help {
  print "\n";
  print "<list>        list installed CPAN modules\n";
  print "<add>         add a new CPAN module to the database\n";
  print "<available>   list available CPAN modules\n";
  print "<remove>      remove a CPAN module\n";
  print "\nUsage: $0 <command>\n\n";
  exit 1;
}

sub virgin {
  return 1 if not exists($CPAN{_virgin});
  return 0;
}


