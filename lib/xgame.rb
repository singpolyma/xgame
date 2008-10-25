# All distances in pixels
# All times in milliseconds
# All velocities in unmodified pixels / millisecond
# All masses in modifier (velocity / mass = speed)

begin
	require 'rubygame'

	# If we are operating without rubygems (preferred) some features are still nice
	# define the Gem class to keep a standard API
	class Gem
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
end

# Extend the Rubygame namespace
module Rubygame

	# This class defines an easy way to manage callbacks
	class ListenerList < Hash
		def addEventListener(event, callback=nil, &block)
			callback = block unless callback
			self[event] = [] unless self.key?event
			self[event] << callback
		end
	end

	class LoopEvent < Event
	end

	# Extend the Sprites namespace
	module Sprites

		# This is a mixin module for sprites that move
		module MovingSprite

			def initialize(*args)
				super
				@velocity = {:left => 0, :right => 0, :up => 0, :down => 0} # These are the initial components of velocity
				@animating = {:left => [0,0], :right => [0,0], :up => [0,0], :down => [0,0]}
				@force = [0,0] # External force being applied
				@reference = [0,0] # Moving frame of reference
				@mass = 1 # This can be overidden by implementations
			end

			def velocity
				[@velocity[:left]*-1 + @velocity[:right], @velocity[:up]*-1 + @velocity[:down]]
			end

			def moving?(direction)
				return velocity[0] + @force[0] > 0 if direction == :right
				return velocity[0] + @force[0] < 0 if direction == :left
				return velocity[1] + @force[1] > 0 if direction == :down
				return velocity[1] + @force[1] < 0 if direction == :up
				false
			end

			def reference=(v)
				@reference = v
			end

			# Go in some direction [vx, vy]. If either is nil, motion on that axis will not be affected.
			def go(v, duration=0)
				if v[0]
					if v[0] <= 0
						@animating[:left] = [duration, @velocity[:left]]
						@velocity[:left] = v[0]*-1
					end
					if v[0] >= 0
						@animating[:right] = [duration, @velocity[:right]]
						@velocity[:right] = v[0]
					end
				end
				if v[1]
					if v[1] <= 0
						@animating[:up] = [duration, @velocity[:up]]
						@velocity[:up] = v[1]*-1
					end
					if v[1] >= 0
						@animating[:down] = [duration, @velocity[:down]]
						@velocity[:down] = v[1]
					end
				end
			end

			# Stop some component of motion
			def stop(direction, duration=0)
				@animating[direction] = [duration, @animating[direction][0] >= 1 ? @animating[direction][1] : @velocity[direction]]
				@velocity[direction] = 0
			end

			def fullstop(direction, duration=0)
				stop(direction,duration)
				@force[0] = 0 if direction == :left or direction == :right
				@force[1] = 0 if direction == :up or direction == :down
			end

			# Strike the sprite in a certain direction
			def hit(v, by=nil)
				self.go(v,[3,XGame.framerate/5].max)
			end

			# Apply a force to this sprite [vx, vy], {:direction => max}
			def apply_force(value, max={})
				max ||= {}
				@force[0] += value[0] if value[0] < 0 and (!max[:left] or @force[0] < max[:left]*-1)
				@force[0] += value[0] if value[0] > 0 and (!max[:right] or @force[0] < max[:right])
				@force[1] += value[1] if value[1] < 0 and (!max[:up] or @force[1] < max[:up]*-1)
				@force[1] += value[1] if value[1] > 0 and (!max[:down] or @force[1] < max[:down])
			end

			def self.included(base)
				base.class_eval {alias_method :update_no_moving, :update; alias_method :update, :update_moving}
			end

			def update_moving(time)
				update_no_moving(time)
				if @animating[:left][0] > 0
					@animating[:left][0] -= 1
					@velocity[:left] = @animating[:left][1] if @animating[:left][0] < 1
				end
				if @animating[:right][0] > 0
					@animating[:right][0] -= 1
					@velocity[:right] = @animating[:right][1] if @animating[:right][0] < 1
				end
				if @animating[:up][0] > 0
					@animating[:up][0] -= 1
					@velocity[:up] = @animating[:up][1] if @animating[:up][0]  < 1
				end
				if @animating[:down][0] > 0
					@animating[:down][0] -= 1
					@velocity[:down] = @animating[:down][1] if @animating[:down][0] < 1
				end

				x,y = @rect.center

				@rect.centerx = x + (@reference[0] + ((@force[0] + velocity[0]) / @mass)) * (time/1000.0)
				@rect.centery = y + (@reference[1] + ((@force[1] + velocity[1]) / @mass)) * (time/1000.0)
				@reference = [0,0] # Frame of reference must be reset every frame
			end

		end # module MovingSprite

		# This is a mixin module to allow a sprite to let things pass through some edges
		module EdgeSprite
			attr_accessor :edges
		end

		# This is a mixin module for groups that keep their sprites in a particular region of the screen
		module BoundedGroup

			# Bounding box (of type Rubygame::Rect)
			attr_writer :bounds
			def bounds
				@bounds ||= Rubygame::Screen.get_surface().make_rect()
			end

			def update(*args)
				super(*args)
				self.each { |sprite|
					if sprite.rect.top < bounds.top
						sprite.rect.top = bounds.top
						sprite.fullstop(:up) if sprite.respond_to?(:fullstop)
					end
					if sprite.rect.bottom > bounds.bottom
						sprite.rect.bottom = bounds.bottom
						sprite.fullstop(:down) if sprite.respond_to?(:fullstop)
					end
					if sprite.rect.left < bounds.left
						sprite.rect.left = bounds.left
						sprite.fullstop(:left) if sprite.respond_to?(:fullstop)
					end
					if sprite.rect.right > bounds.right
						sprite.rect.right = bounds.right
						sprite.fullstop(:right) if sprite.respond_to?(:fullstop)
					end	
				}
			end
			
		end

		# This is a mixin module for groups of sprites with a constant force acting on them
		module ForceGroup
			# Force vector [vx, vy]
			def force=(value)
				@force = value
			end

			def max_force=(value)
				@max_force = value
			end

			def update(*args)
				super(*args)
				force = [@force[0] * (args[0]/1000.0), @force[1] * (args[0]/1000.0)] # Make sure force is applied the same no matter how fast we're rendering
				self.each { |sprite|
					sprite.apply_force(force, @max_force) if sprite.respond_to?(:apply_force)
				}
			end
		end # module ForceGroup

		# This is a mixin module for collisions between sprites
		module CollideGroup

			def update(*args)
				super(*args)
				self.each { |sprite|
					self.each { |sprite2|
						if sprite != sprite2 and sprite.respond_to?(:fullstop) and sprite.collide_sprite?sprite2
							@sprite2_edges = {:top => true, :bottom => true, :left => true, :right => true}
							@sprite2_edges = sprite2.edges if sprite2.respond_to?(:edges)
							d = sprite2.rect.top - sprite.rect.bottom
							if d < 0 and d > -5 and @sprite2_edges[:top] # Sprite is on top
								if !sprite.respond_to?(:moving?) or sprite.moving?:down
									sprite2.hit([nil,sprite.velocity[1]], sprite) if sprite2.respond_to?(:hit) and sprite.respond_to?(:velocity)
									sprite.rect.bottom += d if (!sprite.respond_to?(:edges) or sprite.edges[:bottom])
									sprite.fullstop(:down, 200/args[0])
								end
							end
							d = sprite.rect.top - sprite2.rect.bottom
							if d < 0 and d > -5 and @sprite2_edges[:bottom] # Sprite is on bottom
								if !sprite.respond_to?(:moving?) or sprite.moving?:up
									sprite2.hit([nil,sprite.velocity[1]], sprite) if sprite2.respond_to?(:hit) and sprite.respond_to?(:velocity)
									sprite.rect.top += d if !sprite.respond_to?(:edges) or sprite.edges[:top]
									sprite.fullstop(:up, 200/args[0])
								end
							end
							d = sprite2.rect.left - sprite.rect.right
							if d < 0 and d > -5 and @sprite2_edges[:left] # Sprite is on left
								if !sprite.respond_to?(:moving?) or sprite.moving?:right
									sprite2.hit([sprite.velocity[0],nil], sprite) if sprite2.respond_to?(:hit) and sprite.respond_to?(:velocity)
									sprite.rect.right += d if !sprite.respond_to?(:edges) or sprite.edges[:right]
									sprite.fullstop(:right, 200/args[0])
								end
							end
							d = sprite.rect.left - sprite2.rect.right
							if d < 0 and d > -5 and @sprite2_edges[:right] # Sprite is on right
								if !sprite.respond_to?(:moving?) or sprite.moving?:left
									sprite2.hit([sprite.velocity[0],nil], sprite) if sprite2.respond_to?(:hit) and sprite.respond_to?(:velocity)
									sprite.rect.left += d if (!sprite.respond_to?(:edges) or sprite.edges[:left])
									sprite.fullstop(:left, 200/args[0])
								end
							end
						end
					}
				}
			end
		end

		# This is a basic class for updatable, image-based, sprites with a rectangular box matching their image
		class BasicSprite
			include Rubygame::Sprites::Sprite

			# Override this in subclasses to have a default image
			def self.default_image; end;

			# Create a new BasicSprite. Pass x, y coordinates for location to spawn.
			# Pass path to image if you have not ovrriden default_image
			def initialize(x,y,image=nil)
				super()
				if image
					@image = Rubygame::Surface[image]
					throw "Image #{image} failed to load. Looking in: #{Rubygame::Surface.autoload_dirs.join(":")}" unless @image
				else
					@image = default_image
				end
				@rect = Rubygame::Rect.new(x,y,*@image.size)
			end

			def update(time); end

		end # class BasicMovingBoundedSprit

	end # module Sprites

end # module Rubygame

class XGame

	@@frametime = 15
	def self.frametime
		@@frametime
	end
	def self.framerate
		1000 / @@frametime
	end

	# This method is the heart of XGame. Call it with a block that sets up your program.
	def self.run(title = 'XGame', size = [], frametime = @@frametime, ignore_events = [], &block)

		Rubygame.init() # Set stuff up

#		if Rubygame::Screen.respond_to?(:get_resolution)
#			size[0] = Rubygame::Screen.get_resolution[0] unless size[0]
#			size[1] = Rubygame::Screen.get_resolution[1] unless size[1]
#		else
			size[0] = 640 unless size[0]
			size[1] = 480 unless size[1]
#		end

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
		world.extend(Rubygame::Sprites::DepthSortGroup) # Let them get in front of each other

		# Grab the screen and create a background
		screen = Rubygame::Screen.new(size, 0, [Rubygame::HWSURFACE, Rubygame::NOFRAME])
		background = Rubygame::Surface.new(screen.size)

		# This is where event handlers will get stored
		listeners = Rubygame::ListenerList.new

		# Include the user code
		yield screen, background, world, listeners

		# Refresh the screen once. During the loop, we'll use 'dirty rect' updating
		# to refresh only the parts of the screen that have changed.
		screen.update()

		catch(:quit) do
			loop do
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

				world.undraw(screen, background)
				@@frametime = clock.tick
				world.update(@@frametime)
				screen.update_rects(world.draw(screen))

				screen.title = "#{title} [#{self.framerate} fps]"
			end
		end

		puts "#{title} is Quitting!"
		Rubygame.quit()

	end #run

end #XGame
