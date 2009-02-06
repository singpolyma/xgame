# All distances in pixels
# All times in milliseconds

begin
	require 'rubygame'

	# If we are operating without rubygems (preferred) some features are still nice
	# define the Gem class to keep a standard API
	module Gem
		def self.user_home
			@@user_home ||= find_home
		end

		def self.find_home
			['HOME', 'USERPROFILE'].each do |homekey|
				return ENV[homekey] if ENV[homekey]
			end

			if ENV['HOMEDRIVE'] && ENV['HOMEPATH'] then
				return "#{ENV['HOMEDRIVE']}:#{ENV['HOMEPATH']}"
			end

			begin
				File.expand_path("~")
			rescue
				if File::ALT_SEPARATOR then
					'C:/'
				else
					 '/'
				end
			end
		end
	end
rescue LoadError
	require 'rubygems'
	require 'rubygame'
end


# Extend the Rubygame namespace
module Rubygame

	# This class defines an easy way to manage callbacks
	class ListenerList < Hash
		def initialize(world=nil)
			super()
			@world = world
		end

		def addEventListener(event, callback=nil, &block)
			callback = block unless callback
			if @world and @world.respond_to?:add_collision_func and event.is_a?CollisionEvent
				@world.add_collision_func(event.by, event.to) { |by, to| callback.call(by.sprite || by, to.sprite || to) }
			else
				self[event] = [] unless self.key?event
				self[event] << callback
			end
		end
	end

	class LoopEvent < Event
	end

	class CollisionEvent < Event
		attr_accessor :by, :to
		def initialize(by, to=nil)
			@by = by
			@to = to
		end
	end

	# Extend the Sprites namespace
	module Sprites

		module Sprite 

			# This method lets you check if the sprite is moving in a certain direction
			def moving?(direction)
				false # We're not a moving sprite
			end

			# Call this function every frame to have the Sprite calculate things about itself
			def update(time); end

		end

		# This class basically just turns the Sprite module into an inheritable class
		class BasicSprite
			include Rubygame::Sprites::Sprite
		end

		# This is a basic class for image-based, sprites with a rectangular box matching their image
		class ImageSprite < Rubygame::Sprites::BasicSprite

			# Override this in subclasses to have a default image
			# (actually, Surface, you can just draw vector stuff on it)
			def self.default_image; end;

			# Create a new BasicSprite. Pass x, y coordinates for location to spawn.
			# Pass path to image if you have not ovrriden default_image
			def initialize(x,y,image=nil)
				super()
				if image
					@image = Rubygame::Surface[image]
					raise "Image #{image} failed to load. Looking in: #{Rubygame::Surface.autoload_dirs.join(":")}" unless @image
				else
					@image = default_image
					raise "No image to load. No default image, no image specified." unless @image
				end
				@rect = Rubygame::Rect.new(x,y,*@image.size)
			end

		end # class ImageSprite

		module BackgroundGroup
			attr_reader :background

			def initialize(size)
				super()
				@background = Rubygame::Surface.new(size)
			end

			def draw_background_onto(screen)
				@background.blit(screen, [0, 0])
				screen.update
			end

			def undraw(screen)
				super(screen, @background)
			end
		end

	end # module Sprites

	# Default rubygame clock sucks the CPU. We can do better.
	class Clock
		def tick()
			passed = Clock::runtime - @last_tick # how long since the last tick?
			if @target_frametime and (wait = @target_frametime - passed) > 0
				return Clock::wait(wait) + passed
			end
			return passed
		ensure
			@last_tick = Clock::runtime
			@ticks += 1
		end
	end

end # module Rubygame

module XGame
	# NOTE: Remember to update this in ./configure as well as xgame.gemspec
	VERSION = [0,1,0] # MAJOR, MINOR, PATCH

	class World < Rubygame::Sprites::Group
		include Rubygame::Sprites::UpdateGroup # The world can undraw and draw its Sprites
		include Rubygame::Sprites::DepthSortGroup # Let them get in front of each other
		include Rubygame::Sprites::BackgroundGroup # Let there be a background
	end
end

# This method is the heart of XGame. Call it with a block that sets up your program.
def XGame(title = 'XGame', size = [], frametime = 15, ignore_events = [], &block)

	Rubygame::init # Set stuff up

	if Rubygame::Screen.respond_to?(:get_resolution)
		size[0] = Rubygame::Screen.get_resolution[0] unless size[0]
		size[1] = Rubygame::Screen.get_resolution[1] unless size[1]
	else
		size[0] = 320 unless size[0]
		size[1] = 240 unless size[1]
	end

	# The events queue gets filled up with all user input into our window
	events = Rubygame::EventQueue.new
	events.ignore = ignore_events # Let's save cycles by ignoring events of some types

	# The clock keeps us from eating the CPU
	clock = Rubygame::Clock.new
	clock.target_frametime = frametime # Let's aim to render at some framerate

	# Set up autoloading for Surfaces. Surfaces will be loaded automatically the first time you use Rubygame::Surface["filename"].
	Rubygame::Surface.autoload_dirs = [ File.dirname($0) ] # XXX: this should include other paths depending on the platform

	# Grab the screen and create a background
	screen = Rubygame::Screen.new(size, 0, [Rubygame::HWSURFACE, Rubygame::NOFRAME])
	screen.title = title # Set the window title
	
	# Create a world for sprites to live in
	world = XGame::World.new(screen.size)
	
	# This is where event handlers will get stored
	listeners = Rubygame::ListenerList.new(world)

	# Include the user code
	yield screen, world, listeners

	# Reset jumps when landing on walls
	listeners.addEventListener(Rubygame::CollisionEvent.new(:wall)) { |by, to|
		to.reset_jumps if to.respond_to?:reset_jumps
	}

	# Draw background and Refresh the screen once.
	# During the loop, we'll use 'dirty rect' updating
	# to refresh only the parts of the screen that have changed.
	world.draw_background_onto screen

	catch(:quit) do
		loop do

			world.undraw screen

			events << Rubygame::LoopEvent.new
			events.each do |event|
				case event
				when Rubygame::ActiveEvent
					# ActiveEvent appears when the window gains or loses focus.
					# This helps to ensure everything is refreshed after the Rubygame window has been covered up by a different window.
					screen.update
				when Rubygame::QuitEvent
					# QuitEvent appears when the user closes the window, or otherwise signals they wish to quit
					throw :quit
				else
					listeners[event.class].each { |callback| callback.call(event) } if listeners.key?(event.class)
				end
			end

			world.update(clock.tick)
			screen.update_rects(world.draw(screen))

			screen.title = "#{title} [#{clock.framerate.to_i} fps]" if $DEBUG
		end
	end

	puts "#{title} is Quitting!"
	Rubygame.quit

end #XGame
