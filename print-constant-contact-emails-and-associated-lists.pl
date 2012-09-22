# Copyright 2012 AB ITS Incorporated. 
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.

# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.

# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

# This script was written to use Constant Contact 
# (www.constantcontact.com) APIs to print a list of email addresses
# and the list of mailing lists to which they belong. You need Perl
# and curl to run this script.

# To use it, obtain your Constant Contact API credentials and 
# then use the process at 
# http://community.constantcontact.com/t5/Documentation\
# /Authentication-using-OAuth-2-0-Server-and-Client-Flows/ba-p/38313 
# to authorize your app to make calls against a Constant Contact 
# account. The process should net you a bearer token, which you will
# add to the variable below. Next, specify the Constant Contact 
# username in the $CC_USER variable. Once done, just run the script 
# as "perl -w print-constant-contact-emails-and-associated-lists.pl"
# and wait for the results; the script may take a while to run since 
# Constant Contact only allows retrieval of 50 records at a time, 
# which necessitates multiple GETs due to paging. 

$BEARER='-H "Authorization: Bearer REPLACE-WITH-YOUR-ACCESS-TOKEN" ';
$CC_USER='REPLACE-WITH-CONSTANT-CONTACT-USERNAME';

%mapEmailToListNames=();
main(); 

sub getMembersForList {
	my ($name, $list_url)=@_;
	print $name . "\t...\t" . $list_url . "\n";
	
	my $call_url=$list_url;
	while (defined($call_url)) {
		my $cmd='curl -X GET --sslv3 -ik ' . $BEARER . $call_url;
		my @output=`$cmd`;
		my $next_found=0;
		foreach my $item (@output) {
			# get the next url if it is there
			if ($item =~ m/(\?next\=[0-9a-z\-]+)\" rel=\"next\"/) {
				$next_found=1;
				$call_url=$list_url . $1;
			}
			
			if ($item =~ m/\<EmailAddress\>(.+)\<\/EmailAddress\>/) {
				#print $1 . "\n";
				my $ml=$mapEmailToListNames{$1};
				if (defined($ml)) {
					$ml = $ml . ':' . $name;
				}
				else {
					$ml = $name;
				}
				$mapEmailToListNames{$1}=$ml;
			}
		}
		
		$call_url=undef unless $next_found==1;
		#print "call url [" . $call_url . "]\n";
	}
} # get members for list

sub main {
	# get all the lists
	my $cmd='curl -X GET --sslv3 -ik ' . $BEARER . 'https://api.constantcontact.com/ws/customers/' . $CC_USER . '/lists';
	my @lists=`$cmd`;

	my %pairs=();
	my $url="";
	foreach my $list (@lists) {

		# API sends URL first, then list name
		if ($list =~ m/\<id\>(.+)\<\/id\>/) {
			$url=$1;
			$url =~ s/http/https/g;
			$url .= "/members";
		}
	
		if ($list =~ m/\<Name\>(\D+)\<\/Name\>/) {
			if (defined($url)) {
				$pairs{$1}=$url;
				$url=undef;
			}
		}
	}

	foreach my $key (keys %pairs) {
		#print $key . " " . $pairs{$key} . "\n";
		getMembersForList($key, $pairs{$key});
	}
	
	# print out email address and the lists it is associated with
	foreach my $key (keys %mapEmailToListNames) {
		print $key . "\t[" . $mapEmailToListNames{$key} . "]\n";
	}
} # main
