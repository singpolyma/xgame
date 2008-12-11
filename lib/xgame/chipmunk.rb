require 'chipmunk'

# Extend the CP namespace
module CP
	INFINITY = 1.0/0.0

	module Shape
		attr_accessor :sprite
	end

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

end # CP

# Extend the Rubygame namespace
module Rubygame

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
				@shape.sprite = self
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

			def jump(v, unrealism=3)
				if @jumps < 1
					apply_impulse v + (velocity * unrealism)
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
			
			# Get the current gravity
			def gravity
				space.gravity
			end

			# Set the damping/friction across all space
			def damping=(v)
				space.damping = v
			end

			# Add a sprite to this group
			def <<(sprite)
				unless self.include? sprite
					super
					return unless sprite.respond_to?:shape
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

	end # Sprites

end # Rubygame
