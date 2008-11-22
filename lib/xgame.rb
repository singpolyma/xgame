# All distances in pixels
# All times in milliseconds

begin
	require 'rubygame'
	require 'chipmunk'

	# If we are operating without rubygems (preferred) some features are still nice
	# define the Gem class to keep a standard API
	module Gem
		@@user_home = '/'
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
	require 'chipmunk'
end

# Extend the CP namespace
module CP
	INFINITY = 1.0/0.0

	class Vec2
		ZERO = self.new(0,0)
		
		def [](k)
			case k
				when 0: x
				when 1: y
				else raise ArgumentError.new("Bad CP::Vec2 'index' #{k}")
			end
		end
	end

end

# Extend the Rubygame namespace
module Rubygame

	# This class defines an easy way to manage callbacks
	class ListenerList < Hash
		def world=(w)
			@world = w
		end

		def addEventListener(event, callback=nil, &block)
			callback = block unless callback
			if @world and event.is_a?CollisionEvent
				@world.add_collision_func(event.by, event.to) { |by, to| callback.call(by, to) }
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
		def initialize(by, to)
			@by = by
			@to = to
		end
	end

	class Rect
		def shape_for(body)
			CP::Shape::Poly.new(body, vertices, CP::Vec2::ZERO)
		end

		def vertices
			# Centre of gravity is at 0,0 body position translates to centrex, centrey
			[CP::Vec2.new(width/-2, height/-2), CP::Vec2.new(width/-2, height/2), CP::Vec2.new(width/2, height/2), CP::Vec2.new(width/2, height/-2)]
		end
	end # end Rect

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

		# This is a class for Sprites to be used with the Chipmunk Physics Engine
		# It is a subclass of ImageSprite since overriding defaulit_image
		# with any Surface solves not having an image file
		class ChipmunkPhysicsSprite < ImageSprite

			attr_accessor :shape

			def default_mass; 5; end

			def initialize(x, y, mass=nil, moment=nil, image=nil)
				super(x, y, image)
				mass = default_mass unless mass
				moment = CP::moment_for_poly(mass, @rect.vertices, CP::Vec2::ZERO) unless moment
				body = CP::Body.new(mass, moment)
				@shape = @rect.shape_for(body)
				@shape.u = 1.0 # Need some default friction value
				body.p = CP::Vec2.new(rect.centerx, rect.centery)
				@going = { :left => 0, :right => 0, :up => 0, :down =>0 }
				@jumps = 0
			end

			def velocity
				@shape.body.v
			end

			def moving?(direction)
				return velocity.x > 0 if direction == :right
				return velocity.x < 0 if direction == :left
				return velocity.y > 0 if direction == :down
				return velocity.y < 0 if direction == :up
				false
			end

			# Go in some direction [vx, vy]. If either is nil, motion on that axis will not be affected.
			def go(v)
				if v[0]
					@going[:left] = v[0]*-1	if v[0] <= 0
					@going[:right] = v[0] if v[0] >= 0
				end
				if v[1]
					@going[:up] = v[1]*-1 if v[1] <= 0
					@going[:down] = v[1] if v[1] >= 0
				end
				@shape.surface_v = CP::Vec2.new(@going[:left] + @going[:right]*-1, @going[:up] + @going[:down]*-1)
			end

			# Stop some component of motion
			def stop(direction)
				@going[direction] = 0
				@shape.surface_v = CP::Vec2.new(@going[:left] + @going[:right]*-1, @going[:up] + @going[:down]*-1)
			end

			# Apply a constant force along a certain vector
			def apply_force(force)
				case force
					when Array
						@shape.body.apply_force(CP::Vec2.new(force[0], force[1]), CP::Vec2::ZERO)
					when CP::Vec2
						@shape.body.apply_force(force, CP::Vec2::ZERO)
					else
						raise ArgumentError.new("Bad type for force: #{force.class}")
				end
			end

			def jump(strength=1000)
				if @jumps < 1
					apply_impulse [0, -strength]
					@jumps += 1
				end
			end

			def reset_jumps
				@jumps = 0
			end

			# Apply a momentary force impulse
			def apply_impulse(impulse)
				case impulse
					when Array
						@shape.body.apply_impulse(CP::Vec2.new(impulse[0], impulse[1]), CP::Vec2::ZERO)
					when CP::Vec2
						@shape.body.apply_impulse(impulse, CP::Vec2::ZERO)
					else
						raise ArgumentError.new("Bad type for impulse: #{force.class}")
				end
			end

			def update(time)
				super
				reset_jumps if velocity.y.abs < 1 # XXX: velocity.y == 0 at the exact peak of a jump. not a huge problem in practice?

				#@image = @image.rotozoom(@shape.body.a, 1)
				rect.centerx = @shape.body.p.x
				rect.centery = @shape.body.p.y
			end

		end # ChipmunkPhysicsSprite

		module ChipmunkPhysicsSpaceGroup

			# Get the Chipmunk Space
			def space
				@space ||= CP::Space.new
			end

			# adds a collision callback (usually done by a listener)
			def add_collision_func(by, to)
				@space.add_collision_func(by, to) { |by, to| yield by, to }
			end

			# Set the gravity (set in a vector so that horizontal "gravity" is also possible)
			def gravity=(v)
				case v
					when Array
						space.gravity = CP::Vec2.new(v[0], v[1])
					when CP::Vec2
						space.gravity = v
					when Numeric
						space.gravity = CP::Vec2.new(0, v)
					else
						raise ArgumentError.new("Invalid gravity value type #{v.class}")
				end
			end

			# Set the damping/friction across all space
			def damping=(v)
				space.damping = v
			end

			# Add a sprite to this group
			def push(*args)
				super
				args.each do |sprite|
					next unless sprite.respond_to?:shape
					space.add_body sprite.shape.body unless sprite.shape.body.m == CP::INFINITY
					space.add_shape sprite.shape
				end
			end

			# Add bounds to sides of a rectangle (usually the screen)
			def bound(screen, side)
				case side
					when Array
						side.each { |side| bound(screen, side)  }
						return
					when :top
						side_shape = CP::Shape::Segment.new(CP::Body.new(CP::INFINITY, CP::INFINITY), CP::Vec2::ZERO, CP::Vec2.new(screen.width, 0), 0)
						side_shape.body.p = CP::Vec2.new(0, 0)
					when :bottom
						side_shape = CP::Shape::Segment.new(CP::Body.new(CP::INFINITY, CP::INFINITY), CP::Vec2::ZERO, CP::Vec2.new(screen.width, 0), 0)
						side_shape.body.p = CP::Vec2.new(0, screen.height)
					when :left
						side_shape = CP::Shape::Segment.new(CP::Body.new(CP::INFINITY, CP::INFINITY), CP::Vec2::ZERO, CP::Vec2.new(0, screen.height), 0)
						side_shape.body.p = CP::Vec2.new(0, 0)
					when :right
						side_shape = CP::Shape::Segment.new(CP::Body.new(CP::INFINITY, CP::INFINITY), CP::Vec2::ZERO, CP::Vec2.new(0, screen.height), 0)
						side_shape.body.p = CP::Vec2.new(screen.width, 0)
					else
						raise ArgumentError.new("Invalid side to bound #{side}")
				end
				side_shape.collision_type = :wall
				side_shape.u = 1.0
				space.add_static_shape side_shape
			end

			# Update the Chipmunk space
			def update(time, *args)
				super
				space.step(time/1000.0)
			end

		end # ChipmunkPhysicsSpaceGroup

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
end

# This method is the heart of XGame. Call it with a block that sets up your program.
def XGame(title = 'XGame', size = [], frametime = 15, ignore_events = [], &block)

	Rubygame.init() # Set stuff up

	if Rubygame::Screen.respond_to?(:get_resolution)
		size[0] = Rubygame::Screen.get_resolution[0] unless size[0]
		size[1] = Rubygame::Screen.get_resolution[1] unless size[1]
	else
		size[0] = 320 unless size[0]
		size[1] = 240 unless size[1]
	end

	# The events queue gets filled up with all user input into our window
	events = Rubygame::EventQueue.new()
	events.ignore = ignore_events # Let's save cycles by ignoring events of some types

	# The clock keeps us from eating the CPU
	clock = Rubygame::Clock.new()
	clock.target_frametime = frametime # Let's aim to render at some framerate

	# Set up autoloading for Surfaces. Surfaces will be loaded automatically the first time you use Surface["filename"].
	Rubygame::Surface.autoload_dirs = [ File.dirname($0) ] # XXX: this should include other paths depending on the platform

	# Create a world for sprites to live in
	world = Rubygame::Sprites::Group.new
	world.extend(Rubygame::Sprites::UpdateGroup) # The world can undraw and draw its Sprites
	world.extend(Rubygame::Sprites::DepthSortGroup) # Let them get in front of each other

	# Grab the screen and create a background
	screen = Rubygame::Screen.new(size, 0, [Rubygame::HWSURFACE, Rubygame::NOFRAME])
	screen.title = title # Set the window title
	background = Rubygame::Surface.new(screen.size)

	# This is where event handlers will get stored
	listeners = Rubygame::ListenerList.new
	listeners.world = world

	# Include the user code
	yield screen, background, world, listeners

	# Refresh the screen once. During the loop, we'll use 'dirty rect' updating
	# to refresh only the parts of the screen that have changed.
	screen.update()

	catch(:quit) do
		loop do

			world.undraw(screen, background)

			events.push Rubygame::LoopEvent.new
			events.each do |event|
				case event
				when Rubygame::ActiveEvent
					# ActiveEvent appears when the window gains or loses focus.
					# This helps to ensure everything is refreshed after the Rubygame window has been covered up by a different window.
					screen.update()
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
	Rubygame.quit()

end #XGame
