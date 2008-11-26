#!/usr/bin/env ruby

# Test that it loads
$LOAD_PATH << File.dirname(__FILE__) + '/../lib/'
require 'xgame'

puts 'XGame loaded'

puts 'Running XGame. If it does not close automatically, event handlers are broken.'

XGame('TITLE', [1, 1], 20) { |screen, world, listeners|
	puts 'In XGame'

	raise 'Screen title is set wrong' unless screen.title == 'TITLE'
	raise 'Screen size is set wrong' unless screen.height == 1 and screen.width == 1
	raise "Bad type for Background: #{world.background.class}" unless world.background.is_a?Rubygame::Surface 

	# This should work, the image should load, etc
	world.push Rubygame::Sprites::ImageSprite.new(0,0,'panda.png')
	world.each { |sprite| sprite.moving?:left }

	world.extend(Rubygame::Sprites::ChipmunkPhysicsSpaceGroup) # The world has physics
	world.bound(screen, [:top, :bottom, :left, :right]) # Keep sprites on the screen
	world.damping = 0.5 # Set up basic air resistance
	world.gravity = 100 # Set a gravity constant

	panda = Rubygame::Sprites::ChipmunkPhysicsSprite.new(0, 0, 5, CP::INFINITY, 'panda.png')
	world.push panda
	world.each { |sprite| sprite.go([10,10]) if sprite.respond_to?:go }
	panda.stop(:up)
	panda.apply_force([10,10])
	panda.jump

	count = 0
	listeners.addEventListener(Rubygame::LoopEvent) {
		count += 1
		throw :quit if count > 15 # Throwing :quit should end the game loop and clean up
	}
}
