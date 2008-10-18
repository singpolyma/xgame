require 'rubygems'
require 'rubygame'

# Extend the Rubygame namespace
module Rubygame

	# This class defines an easy way to manage callbacks
	class Callbacks < Hash
		def []=(k,v)
			super(k, []) unless self[k]
			self[k].push v
		end
	end

	# Extend the Sprites namespace
	module Sprites

		# This is a mixin module for sprites that move
		module MovingSprite

			def initialize(*args)
				super
				@velocity = {:left => 0, :right => 0, :up => 0, :down => 0} # These are the initial components of velocity
				@reference = [0,0] # Moving frame of reference
				@animating = {:left => [0,0], :right => [0,0], :up => [0,0], :down => [0,0]}
				@speed = 50 # This can be overidden by implementations: it is how fast / massive the sprite is
				@time = 40 # Used to store frametime for internal calculations
			end

			def velocity
				[@velocity[:left]*-1 + @velocity[:right], @velocity[:up]*-1 + @velocity[:down]]
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
				@animating[direction] = [duration, @velocity[direction]]
				@velocity[direction] = 0
			end

			# Strike the sprite in a certain direction
			def hit(v, by=nil)
				self.go(v,[2,(1/(@time/1000.0))/(@speed/4)].max)
			end

			# Apply a force to this sprite [vx, vy, max_applied (optional)]
			def apply_force(value)
				@velocity[:left] += value[0]*-1 if value[0] < 0 and (!value[2][:left] or @velocity[:left] < value[2][:left])
				@velocity[:right] += value[0] if value[0] > 0 and (!value[2][:right] or @velocity[:right] < value[2][:right])
				@velocity[:up] += value[1]*-1 if value[1] < 0 and (!value[2][:up] or @velocity[:up] < value[2][:up])
				@velocity[:down] += value[1] if value[1] > 0 and (!value[2][:down] or @velocity[:down] < value[2][:down])
			end

			def self.included(base)
				base.class_eval {alias_method :update_no_moving, :update; alias_method :update, :update_moving}
			end

			def update_moving(time)
				update_no_moving(time)
				@time = time

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
				base = @speed * time/1000.0

				@rect.centerx = x + (@reference[0] + velocity[0]) * base
				@rect.centery = y + (@reference[1] + velocity[1]) * base
				@reference = [0,0] # Frame of reference must be reset every frame
			end

		end # module MovingSprite

		# This is a mixin module for sprites that are stuck in a bounding box
		module BoundedSprite

			def initialize(*args)
				super
				@bounds = Rubygame::Screen.get_surface().make_rect() # Sprites implementing this module can override this to set the rect for the bounding box
			end

			def self.included(base)
				base.class_eval {alias_method :update_no_bounded, :update; alias_method :update, :update_bounded}
			end

			def update_bounded(time)
				update_no_bounded(time)
				if @rect.top < @bounds.top
					@rect.top = @bounds.top
					self.stop(:up) if self.respond_to?(:stop)
				end
				if @rect.bottom > @bounds.bottom
					@rect.bottom = @bounds.bottom
					self.stop(:down) if self.respond_to?(:stop)
				end
				if @rect.left < @bounds.left
					@rect.left = @bounds.left
					self.stop(:left) if self.respond_to?(:stop)
				end
				if @rect.right > @bounds.right
					@rect.right = @bounds.right
					self.stop(:right) if self.respond_to?(:stop)
				end
			end
		end

		# This is a mixin module to allow a sprite to let things pass through some edges
		module EdgeSprite
			attr_accessor :edges
		end

		# This is a mixin module for groups of sprites with a constant force acting on them
		module ForceGroup
			def force=(value) # Force vector [vx, vy, max_applied (optional)]
				value[2] = {} unless value
				@force = value
			end

			def update(*args)
				super(*args)
				force = [@force[0] * args[0]/1000.0, @force[1] * args[0]/1000.0, @force[2]] # Make sure force is applied the same no matter how fast we're rendering
				self.each { |sprite|
					sprite.apply_force(force) if sprite.respond_to?(:apply_force)
				}
			end
		end # module ForceGroup

		# This is a mixin module for collisions between sprites
		module CollideGroup

			def update(*args)
				super(*args)
				self.each { |sprite|
					self.each { |sprite2|
						next if sprite == sprite2
						if sprite.collide_sprite?sprite2
							@sprite2_edges = {:top => true, :bottom => true, :left => true, :right => true}
							@sprite2_edges = sprite2.edges if sprite2.respond_to?(:edges)
							d = sprite2.rect.top - sprite.rect.bottom
							if d < 0 and d > -15 and @sprite2_edges[:top] # Sprite is on top
								sprite2.hit([nil,sprite.velocity[1]], sprite) if sprite2.respond_to?(:hit) and sprite.respond_to?(:velocity) and sprite.velocity[1] > 0
								sprite.stop(:down, 1/(args[0]/1000.0) * 0.1) if sprite.respond_to?(:stop)
							end
							d = sprite.rect.top - sprite2.rect.bottom
							if d < 0 and d > -15 and @sprite2_edges[:bottom] # Sprite is on bottom
								sprite2.hit([nil,sprite.velocity[1]], sprite) if sprite2.respond_to?(:hit) and sprite.respond_to?(:velocity) and sprite.velocity[1] < 0
								sprite.stop(:up, 1/(args[0]/1000.0) * 0.1) if sprite.respond_to?(:stop)
							end
							d = sprite2.rect.left - sprite.rect.right
							if d < 0 and d > -15 and @sprite2_edges[:left] # Sprite is on left
								sprite2.hit([sprite.velocity[0],nil], sprite) if sprite2.respond_to?(:hit) and sprite.respond_to?(:velocity) and sprite.velocity[0] > 0
								sprite.stop(:right, 1/(args[0]/1000.0) * 0.1) if sprite.respond_to?(:stop)
							end
							d = sprite.rect.left - sprite2.rect.right
							if d < 0 and d > -15 and @sprite2_edges[:right] # Sprite is on right
								sprite2.hit([sprite.velocity[0],nil], sprite) if sprite2.respond_to?(:hit) and sprite.respond_to?(:velocity) and sprite.velocity[0] < 0
								sprite.stop(:left, 1/(args[0]/1000.0) * 0.1) if sprite.respond_to?(:stop)
							end
						end
					}
				}
			end
		end

		# This is a basic class for updatable, image-based, sprites with a rectangular box matching their image
		class BasicSprite
			include Rubygame::Sprites::Sprite
		  
			def initialize(x,y,image)
				super()
				@image = Rubygame::Surface[image]
				throw "Image #{image} failed to load. Looking in: #{Rubygame::Surface.autoload_dirs.join(":")}" unless @image
				@rect = Rubygame::Rect.new(x,y,*@image.size)
			end

			def update(time); end

		end # class BasicMovingBoundedSprit

	end # module Sprites

end # module Rubygame

# This method is the heart of XGame. Call it with a block that sets up your program.
def XGame(title = 'XGame', size = [640, 480], framerate = 40, ignore_events = [], &block)

	Rubygame.init() # Set stuff up

	# The events queue gets filled up with all user input into our window
	events = Rubygame::EventQueue.new()
	events.ignore = ignore_events # Let's save cycles by ignoring events of some types

	# The clock keeps us from eating the CPU
	clock = Rubygame::Clock.new()
	clock.target_framerate = framerate # Let's aim to render at some framerate

	# Set up autoloading for Surfaces. Surfaces will be loaded automatically the first time you use Surface["filename"].
	Rubygame::Surface.autoload_dirs = [ File.dirname($0) ] # XXX: this should include other paths depending on the platform

	# Create a world for sprites to live in
	world = Rubygame::Sprites::Group.new
	world.extend(Rubygame::Sprites::UpdateGroup) # Make it update them
	world.extend(Rubygame::Sprites::DepthSortGroup) # Let them get in front of each other
	world.extend(Rubygame::Sprites::ForceGroup) # Let a constant force (likely gravity) be applied to them

	# Grab the screen and create a background
	screen = Rubygame::Screen.new(size, 0, [Rubygame::HWSURFACE, Rubygame::NOFRAME])
	background = Rubygame::Surface.new(screen.size)

	# This is where event handlers will get stored
	callbacks = Rubygame::Callbacks.new

	# Include the user code
	yield screen, background, world, callbacks

	# Refresh the screen once. During the loop, we'll use 'dirty rect' updating
	# to refresh only the parts of the screen that have changed.
	screen.update()

	catch(:quit) do
		loop do
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
					callbacks[event.class].each { |callback| callback.call(event) } if callbacks[event.class]
				end
			end

			world.undraw(screen, background)
			world.update(clock.tick)
			screen.update_rects(world.draw(screen))

			screen.title = "#{title} [#{clock.framerate.to_i} fps]"
		end
	end

	puts "#{title} is Quitting!"
	Rubygame.quit()

end #XGame
