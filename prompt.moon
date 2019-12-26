#!/usr/bin/env moon
if arg[1]=='--help' or arg[1]=='-h'
	local scriptpath
	do
		fd=io.popen "realpath '#{arg[0]}'"
		scriptpath=fd\read '*l'
		fd\close!
	io.write "Usage: prompt <lastexit> <cwd> <username> <hostname>\n"
	io.write "For bash: PROMPT_COMMAND='PS1=\"`moon #{scriptpath}` $? \\`pwd\\` \\`whoami\\` \\`hostname\\``\"'\n"
	io.write "For fish: function fish_prompt --description 'a powerline-like prompt for any shell'; moon #{scriptpath} $status (pwd) (whoami) (hostname); end\n"
	os.exit 0

{lastexit, cwd, username, hostname, options}=arg
lastexit=tonumber lastexit
oneline=options and options\match 'o'
nopowerline=options and options\match 'P'
dumbterminal=options and options\match 'd'

if #arg!=4 and #arg!=5
	io.stderr\write "Usage: prompt <lastexit> <cwd> <username> <hostname> [options]\n"
	io.stderr\write "\tprompt --help\n"
	os.exit 1

colors={
	statusok: '228822'
	statusko: 'aa2222'
	
	battery: '8822aa'
	time: '5522aa'
	username: '2222aa'
	hostname: '2255aa'
	cwd: '2288aa'
	
	gitrepo: 'aa22aa'
	gitbranch: 'aa55aa'
	gitstatus: 'aa88aa'
}
dumbcolors={
	statusok: 2
	statusko: 1
	
	battery: 5
	time: 4
	username: 3
	hostname: 7
	cwd: 4
	
	gitrepo: 5
	gitbranch: 4
	gitstatus: 2
}
powerlineterminals={
	'xterm-kitty': true
}
goodterminals={
	'xterm-kitty': true
	'linux': true
}
batterypath='/sys/class/power_supply/BAT1/capacity'

hextable={(tostring i), i for i=0, 9}
hextable[string.char a+string.byte 'a']=a+10 for a=0, 5
esc="#{string.char(0x1b)}["
nopowerline=true unless powerlineterminals[os.getenv 'TERM']
dumbterminal=true unless goodterminals[os.getenv 'TERM']

exec= (line) ->
	a=os.execute line
	return a==0 or a==true
execl= (line) ->
	fd=io.popen line, 'r'
	rst=fd\read '*l'
	fd\close!
	return rst
exect= (line) ->
	fd=io.popen line, 'r'
	lines=[line for line in fd\lines!]
	fd\close!
	return lines

readl= (path) ->
	fd=io.open path, 'r'
	rst=fd\read '*l'
	fd\close!
	return rst

hextodec= (hex) ->
	n=0
	for i=1, #hex
		n=16*n+hextable[hex\sub i, i]
	return n

getcolor= (name, bg=false) ->
	color=colors[name] or 'ffffff'
	return "#{esc}#{bg and 48 or 38};2;#{hextodec color\sub 1, 2};#{hextodec color\sub 3, 4};#{hextodec color\sub 5, 6}m"
getdumbcolor= (name) ->
	color=dumbcolors[name] or '7'
	return "#{esc}3#{color}m"

shortenpath= (path) ->
	if path=='/' or path=='.'
		return path
	home=os.getenv 'HOME' or "/home/#{username}"
	if (path\sub 1, #home)==home
		path="~#{path\sub #home+1}"
	
	shorten=(e) ->
		if (e\sub 1, 1)=='.'
			return e\sub 1, 2
		return e\sub 1, 1
	
	sp=[e for e in path\gmatch '[^/]+']
	for i, e in ipairs sp
		if i!=#sp
			sp[i]=shorten e
	return table.concat sp, '/'

render= (blocks) ->
	if dumbterminal
		for i, block in ipairs blocks
			io.write "#{getdumbcolor block.color} #{block.text}"
		io.write "#{esc}0m "
	else
		for i, block in ipairs blocks
			io.write "#{getcolor block.color, true} #{block.text} "
			if nopowerline
				if i==#blocks
					io.write "#{esc}0m "
				else
					io.write getcolor blocks[i+1]
			else
				if i==#blocks
					io.write "#{esc}49m#{getcolor block.color, false}#{esc}0m "
				else
					io.write "#{getcolor block.color, false}#{getcolor blocks[i+1].color, true}#{esc}39m"

blocks={}
do -- first line: status, time, username, hostname, directory
	if lastexit==0
		table.insert blocks, {text: 0, color: 'statusok'}
	else
		table.insert blocks, {text: lastexit, color: 'statusko'}
	pcall () -> table.insert blocks, {text: "#{readl batterypath}%", color: 'battery'}
	table.insert blocks, {text: (os.date '%H:%M'), color: 'time'}
	table.insert blocks, {text: username, color: 'username'}
	table.insert blocks, {text: hostname, color: 'hostname'}
	table.insert blocks, {text: (shortenpath cwd), color: 'cwd'}
unless oneline
	render blocks
	blocks={}

do -- second line: git repo, git branch, git status
	repo=execl 'git rev-parse --git-dir 2>/dev/null'
	if repo
		repo=shortenpath execl "dirname '#{repo}'"
		branches=[{active: (branch\match '%*'), name: (branch\match '[%s*]*(.+)%s*')} for branch in *(exect 'git branch -l')]
		branch=([branch.name for branch in *branches when branch.active])[1] or "no branch"
		changes=#exect 'git status --porcelain'
		if changes==0
			changes='clean'
		elseif changes==1
			changes='1 change'
		else
			changes..=' changes'
		io.write '\n'
		blocks={} unless oneline
		table.insert blocks, {text: repo, color: 'gitrepo'} unless oneline
		table.insert blocks, {text: branch, color: 'gitbranch'}
		table.insert blocks, {text: changes, color: 'gitstatus'}
render blocks
