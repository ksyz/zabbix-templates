# script used to adjust, filter, transform original mysql template
# maybe will be useful later.

use strict;
use warnings;
use Data::Dumper;

use XML::XPath;
use XML::XPath::XMLParser;

my $xp = XML::XPath->new(filename => $ARGV[0]);

my $instance = $ARGV[1];

{
	# remove triggers
	my $nodeset = $xp->find('/zabbix_export/hosts/host/triggers');
	my $triggers = $nodeset->pop();
	my $parent = $triggers->getParentNode();
	$parent->removeChild($triggers);
}

my $nodeset = $xp->find('/zabbix_export/hosts/host/items/item');

foreach my $node ($nodeset->get_nodelist) {
	my $description_nodeset = $node->find('description');
	my $raw_description = $description_nodeset->string_value;

	if ($raw_description =~ /^suggest/i or $raw_description =~ /^change/i) {
		my $parent = $node->getParentNode;
		$parent->removeChild($node);
		next;
	}


	# MySQL: Konsky: Kokot -> Application is "MySQL: Konsky" and Item is "Kokot"
	# MySQL: Jelen -> Application is "MySQL" and Item is "Jelen"
	if ($raw_description =~ /^(?:[^:]*: )?(\S+):(.*)/) {

		# print "application $1\n";
		my $guess_app = $1;
		chomp $guess_app;
		$guess_app =~ s/^\s+//g;
		
		my $item_name = $2;
		chomp $item_name;
		$item_name =~ s/^\s+//g;
	
		# description remove and new
		my $description_node = $description_nodeset->pop;
		$node->removeChild($description_node);
	
		my $dn = XML::XPath::Node::Element->new("description");
		my $dt = XML::XPath::Node::Text->new($item_name);
		$dn->appendChild($dt);
		$node->appendChild($dn);

		# application is "prefix:" if set, "MySQL" (default) otherwise
		my $app_node = $node->find('applications/application');
		for my $app ($app_node->get_nodelist) {
			if ($app->string_value =~ /MySQL/) {
				my $parent = $app->getParentNode;
				$parent->removeChild($app);
				warn $guess_app;
				my $n = XML::XPath::Node::Element->new("application");
				my $t = XML::XPath::Node::Text->new("MySQL Stats".($instance ne "" ? " (\U$instance)" : "").": ".$guess_app);
				
				$n->appendChild($t);
				$parent->appendChild($n);
			}
		}
	}
	else {
		# application is "prefix:" if set, "MySQL" (default) otherwise
		my $app_node = $node->find('applications/application');
		for my $app ($app_node->get_nodelist) {
			my $parent = $app->getParentNode;
			$parent->removeChild($app);
			my $n = XML::XPath::Node::Element->new("application");
			my $t = XML::XPath::Node::Text->new("MySQL Stats (\U$instance)");
			$n->appendChild($t);
			$parent->appendChild($n);
		}
	}
	
	# $app_node = $node->find('applications');
	# map { print " applications -".$_->string_value."-\n"; } $app_node->get_nodelist;

	# XML::XPath::XMLParser::as_string($node), "\n\n";
}

my $nodelist = $xp->find('/');
my $text = "";
for my $node ($nodelist->get_nodelist()) {
	$text .= XML::XPath::XMLParser::as_string($node);
}

if ($instance ne "") {
	$text =~ s/mysql##/mysql-\L$instance/g;
	$text =~ s/Template_MySQL_Server##/Template_MySQL_Server_(\U$instance)/g;
}
else {
	$text =~ s/##//g;
}

print $text;
1;
