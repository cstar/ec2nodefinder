{application, ec2nodefinder, 
[{description, "automatic node discovery on EC2"}, 
{vsn, "0.11"}, 
{modules, [awssign, ec2nodefinder, ec2nodefindersrv, ec2nodefindersup]},
{registered,[ec2nodefinder]}, 
{applications, [kernel,stdlib, inets, crypto]}, 
{mod, {ec2nodefinder,[]}},
{start_phases, []},
{env, [
	{ping_timeout_sec, 10}
%	{access, ""},
%	{secret, ""}
]}
]}. 
