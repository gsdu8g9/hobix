#
# = hobix/commandline.rb
#
# Hobix command-line weblog system.
#
# Copyright (c) 2003-2004 why the lucky stiff
#
# Written & maintained by why the lucky stiff <why@ruby-lang.org>
#
# This program is free software. You can re-distribute and/or
# modify this program under the same terms of ruby itself ---
# Ruby Distribution License or GNU General Public License.
#
#--
# $Id$
#++
require 'hobix'

module Hobix
module CommandLine
    ##
    ## Locate RC
    ##
    [
        [ENV['HOME'], ENV['HOME']],
        [ENV['APPDATA'], File.join( ENV['APPDATA'], 'Hobix' )]
    ].each do |home_top, home_dir|
        next unless home_top
        if File.exists? home_top
            File.makedirs( home_dir )
            HOME_DIR = home_dir
            break
        end
    end
    RC = File.join( HOME_DIR, '.hobixrc' )

    def login
        @config = YAML::load( File.open( RC ) ) if File.exists? RC
    end

    def config
        @config
    end

    def save_config
        File.open( RC, "w" ) do |f|
            f.write @config.to_yaml
        end
    end

    # Create a new skeleton for a weblog
    def create_weblog_explain; "Create a brand new weblog."; end
    def create_weblog_args; ['weblog-name']; end
    def create_weblog( name )
    end


    # Add a weblog to local config
    def add_weblog_explain; "Adds a pre-existing hobix weblog to your list."; end
    def add_weblog_args; ['weblog-name', '/path/to/hobix.yaml']; end
    def add_weblog( name, path )
        @config['weblogs'] ||= {}
        @config['weblogs'][name] = path
        save_config
    end

    # Edit a weblog from local config
    def edit_action_explain; "Edit weblog's configuration"; end
    def edit_action_args; ['weblog-name']; end
    def edit_action( weblog )
        webconf = aorta( weblog )
        return if webconf.nil?
    end

    # Delete a weblog from local config
    def del_weblog_explain; "Remove weblog from your list."; end
    def del_weblog_args; ['weblog-name']; end
    def del_weblog( name )
        @config['weblogs'] ||= {}
        @config['weblogs'].delete( name )
        save_config
    end

    # List entries
    def list_action_explain; "List all posts within a given path."; end
    def list_action_args; ['weblog-name', 'search/path']; end
    def list_action( weblog, inpath = '' )
        entries = weblog.storage.find( :all => true, :inpath => inpath ).
                  sort { |e1, e2| e1[0] <=> e2[0] }
        name_width = entries.collect { |e| e[0].length }.max + 1
        tabular( entries, [[-name_width, 0, 'shortName'], [-34, 1, 'created']] )
    end

    # Post a new entry
    def post_action_explain; "Add or edit a post with identifier 'shortName'.\n" +
        "(You can use full paths. 'blog/weddings/anotherPatheticWedding')"; end
    def post_action_args; ['weblog-name', 'shortName']; end
    def post_action( weblog, entry_id )
        begin
            entry = weblog.storage.load_entry( entry_id )
        rescue
            entry = Hobix::Entry.new
            entry.author = @config['username']
        end
        entry = aorta( entry )
        return if entry.nil?

        weblog.storage.save_entry( entry_id, entry )
        weblog.regenerate( :update ) if @config['post upgen']
    end

    # Update the site
    def upgen_action_explain; "Update site with only the latest changes."; end
    def upgen_action_args; ['weblog-name']; end
    def upgen_action( weblog )
        weblog.regenerate( :update )
    end

    # Regenerate the site
    def regen_action_explain; "Regenerate the all the pages throughout the site."; end
    def regen_action_args; ['weblog-name']; end
    def regen_action( weblog )
        weblog.regenerate
    end

    ##          
    ## Setup user's RC
    ##
    def setup
        @config = {}

        username = ''
        default_user = ''
        user_prompt = 'Your hobix username'
        if ENV['USER']
            default_user = ENV['USER']
            user_prompt << " [<Enter> for #{ ENV['USER'] }]"
        end
        while username.empty?
            puts
            print "#{ user_prompt }: "
            username = gets.strip
            if username.empty?
                username = default_user
            end
        end
        @config['username'] = username

        puts
        puts "Your EDITOR environment variable is set to '#{ ENV['EDITOR'] }'."
        puts "You can edit entries with your EDITOR or you can just use hobix."
        print "Use your EDITOR to edit entries? [y/N]: "
        editor = gets.strip.upcase

        if editor == 'Y'
            @config['use editor'] = true
        else
            @config['use editor'] = false
        end

        puts
        puts "When posting a new entry, would you like Hobix to automatically"
        print "update the site? [Y/n]: "
        post_upgen = gets.strip.upcase

        if post_upgen == 'N'
            @config['post upgen'] = false
        else
            @config['post upgen'] = true
        end

        # puts
        # puts "If you want to create a new hobix weblog, we can do that now."
        # puts "Each weblog needs a name and a path.  Use <ENTER> at any prompt"
        # puts "to simply move on."
        # @config['weblogs'] ||= {}
        # ## XX TODO XX

        # puts
        # puts "If you want to join an existing hobix weblog, we can do that now."
        # puts "Each weblog needs a name and a path.  Use <ENTER> at any prompt"
        # puts "to simply move on."
        # ## XX TODO XX
        save_config
    end

    def aorta( obj )
        tempfile = File.join(ENV['TMPDIR']||ENV['TMP']||ENV['TEMP']||'/tmp',"%10.6f.hobix" % Time.now())
        File.open( tempfile, 'w' ) { |f| f << obj.to_yaml }
        created = File.mtime( tempfile )
        system( "#{ ENV['EDITOR'] || 'vi' } #{ tempfile }" )
        return nil unless File.exists?( tempfile )

        if created < File.mtime( tempfile )
            obj = YAML::load( File.open( tempfile ) )
        else
            puts "** Edit aborted"
            obj = nil
        end
        File.delete( tempfile )
        obj
    end

    def tabular( table, fields, desc = nil )
        client_format = fields.collect { |f| "%#{ f[0] }s" }.join( ': ' )
        puts client_format % fields.collect { |f| f[2] }
        puts fields.collect { |f| "-" * f[0].abs }.join( ':-' )
        table.each do |row|
            puts client_format % fields.collect { |f| row[ f[1] ] }
            if desc
                puts row[ desc ]
                puts
            end
        end
    end

end
end
