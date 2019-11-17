--[[
    GD50
    Breakout Remake

    -- PlayState Class --

    Author: Colton Ogden
    cogden@cs50.harvard.edu

    Represents the state of the game in which we are actively playing;
    player should control the paddle, with the ball actively bouncing between
    the bricks, walls, and the paddle. If the ball goes below the paddle, then
    the player should lose one point of health and be taken either to the Game
    Over screen if at 0 health or the Serve screen otherwise.
]]

PlayState = Class{__includes = BaseState}

--[[
    We initialize what's in our PlayState via a state table that we pass between
    states as we go from playing to serving.
]]
function PlayState:enter(params)
    self.paddle = params.paddle
    self.bricks = params.bricks
    self.health = params.health
    self.score = params.score
    self.highScores = params.highScores

    -- Assignment 2: 
    -- allow more than one ball
    self.balls = {params.ball}
    self.numBalls = 1

    self.level = params.level
    self.recoverPoints = 5000

    -- give ball random starting velocity
    self.balls[1].dx = math.random(-200, 200)
    self.balls[1].dy = math.random(-50, -60)

    -- Assignment 2:
    -- Table with powerups 
    -- Keep track of whether the user has the key powerup or not
    self.powerups = {}
    self.key = false

end



function PlayState:update(dt)
    if self.paused then
        if love.keyboard.wasPressed('space') then
            self.paused = false
            gSounds['pause']:play()
        else
            return
        end
    elseif love.keyboard.wasPressed('space') then
        self.paused = true
        gSounds['pause']:play()
        return
    end

    -- update paddle position
    self.paddle:update(dt)

    -- Assignment 2:
    -- update multiple balls
    for k, ball in pairs(self.balls) do 

        ball:update(dt)
     
        if ball:collides(self.paddle) then
            -- raise ball above paddle in case it goes below it, then reverse dy
            ball.y = self.paddle.y - 8
            ball.dy = -ball.dy

            --
            -- tweak angle of bounce based on where it hits the paddle
            --

            -- if we hit the paddle on its left side while moving left...
            if ball.x < self.paddle.x + (self.paddle.width / 2) and self.paddle.dx < 0 then
                ball.dx = -50 + -(8 * (self.paddle.x + self.paddle.width / 2 - ball.x))
            
            -- else if we hit the paddle on its right side while moving right...
            elseif ball.x > self.paddle.x + (self.paddle.width / 2) and self.paddle.dx > 0 then
                ball.dx = 50 + (8 * math.abs(self.paddle.x + self.paddle.width / 2 - ball.x))
            end
            gSounds['paddle-hit']:play()
        end
    
        -- detect collision across all bricks with the ball
        for k, brick in pairs(self.bricks) do

            -- only check collision if we're in play
            if brick.inPlay and ball:collides(brick) then


                -- trigger the brick's hit function, which removes it from play
                -- Assignment 2: pass in to Brick whether the player has the key or not
                -- Give more points if unlocking locked brick
                if self.key and brick.locked then
                    self.score = self.score + 5000
                elseif brick.locked then
                    -- Do not give points when brick is locked
                else 
                    self.score = self.score + (brick.tier * 200 + brick.color * 25)
                end
                
                brick:hit(self.key)

                -- if we have enough points, recover a point of health
                if self.score > self.recoverPoints then
                    -- can't go above 3 health
                    self.health = math.min(3, self.health + 1)

                    -- multiply recover points by 2
                    self.recoverPoints = math.min(100000, self.recoverPoints * 2)

                    -- Assignment 2: 
                    -- Increase size of paddle
                    if self.paddle.size < 4 then
                        self.paddle:resize(self.paddle.size + 1)
                    end

                    -- play recover sound effect
                    gSounds['recover']:play()
                end


                -- Assignment 2: 
                -- random powerup at random intervals when hitting brick
                if math.random(100) < 20 then  -- % chance of getting a powerup
                    if math.random(100) < 25 then -- if powerup, 25 % chance it's a key
                        powertype = 10
                    else
                        powertype = math.random(9) --random powerup
                    end
                    pwr = Powerup(powertype, ball.x, ball.y)
                    table.insert(self.powerups, pwr)
                end

                -- go to our victory screen if there are no more bricks left
                if self:checkVictory() then
                    gSounds['victory']:play()

                    gStateMachine:change('victory', {
                        level = self.level,
                        paddle = self.paddle,
                        health = self.health,
                        score = self.score,
                        highScores = self.highScores,
                        ball = ball,
                        recoverPoints = self.recoverPoints
                    })
                end


                --
                -- collision code for bricks
                --
                -- we check to see if the opposite side of our velocity is outside of the brick;
                -- if it is, we trigger a collision on that side. else we're within the X + width of
                -- the brick and should check to see if the top or bottom edge is outside of the brick,
                -- colliding on the top or bottom accordingly 
                --

                -- left edge; only check if we're moving right, and offset the check by a couple of pixels
                -- so that flush corner hits register as Y flips, not X flips
                if ball.x + 2 < brick.x and ball.dx > 0 then
                    
                    -- flip x velocity and reset position outside of brick
                    ball.dx = -ball.dx
                    ball.x = brick.x - 8
                
                -- right edge; only check if we're moving left, , and offset the check by a couple of pixels
                -- so that flush corner hits register as Y flips, not X flips
                elseif ball.x + 6 > brick.x + brick.width and ball.dx < 0 then
                    
                    -- flip x velocity and reset position outside of brick
                    ball.dx = -ball.dx
                    ball.x = brick.x + 32
                
                -- top edge if no X collisions, always check
                elseif ball.y < brick.y then
                    
                    -- flip y velocity and reset position outside of brick
                    ball.dy = -ball.dy
                    ball.y = brick.y - 8
                
                -- bottom edge if no X collisions or top collision, last possibility
                else
                    
                    -- flip y velocity and reset position outside of brick
                    ball.dy = -ball.dy
                    ball.y = brick.y + 16
                end

                -- slightly scale the y velocity to speed up the game, capping at +- 150
                if math.abs(ball.dy) < 150 then
                    ball.dy = ball.dy * 1.02
                end

                -- only allow colliding with one brick, for corners
                break
            end
        end

        -- Assignment 2:
        -- Update powerup +
        -- collision detection for powerup and paddle
        for k, powerup in pairs(self.powerups) do
            powerup:update(dt)
            if powerup:collides(self.paddle) then
                gSounds['power']:play()
                if powerup.powertype < 10 then
                     self:bonusBalls()  
                end       
                if powerup.powertype == 10 then
                    self.key = true
                end  
                table.remove(self.powerups, k)
            end
            -- remove powerup from table when outside screen
            if powerup.y > VIRTUAL_HEIGHT +16 then
                table.remove(self.powerups, k)
            end
        end


        -- if ball goes below bounds, revert to serve state and decrease health
        if ball.y >= VIRTUAL_HEIGHT then
            if self.numBalls <= 1 then 
                self.health = self.health - 1
                gSounds['hurt']:play()

                -- Assignment 2:
                -- Decrease size of paddle when loosing one heart
                if self.paddle.size > 1 then
                    self.paddle:resize(self.paddle.size -1)
                end

                if self.health == 0 then
                    gStateMachine:change('game-over', {
                        score = self.score,
                        highScores = self.highScores
                    })
                else
                    gStateMachine:change('serve', {
                        paddle = self.paddle,
                        bricks = self.bricks,
                        health = self.health,
                        score = self.score,
                        highScores = self.highScores,
                        level = self.level,
                        recoverPoints = self.recoverPoints
                    })
                end
            else
                table.remove( self.balls, k )
                self.numBalls = self.numBalls - 1
            end
        end

    end

    -- for rendering particle systems
    for k, brick in pairs(self.bricks) do
        brick:update(dt)
    end

    if love.keyboard.wasPressed('escape') then
        love.event.quit()
    end



end



function PlayState:render()
    -- render bricks
    for k, brick in pairs(self.bricks) do
        brick:render()
    end

    -- render all particle systems
    for k, brick in pairs(self.bricks) do
        brick:renderParticles()
    end

    self.paddle:render()

    for k, ball in pairs(self.balls) do
        ball:render()
    end
    
    for k, powerup in pairs(self.powerups) do
        powerup:render()
    end


    renderScore(self.score)
    renderHealth(self.health)

    -- Assignment 2:
    -- Show key symbol if player has key powerup
    if self.key then
        love.graphics.draw(gTextures['main'], gFrames['power'][10],VIRTUAL_WIDTH - 116, 3, 0, 0.6)
    end

    -- pause text, if paused
    if self.paused then
        love.graphics.setFont(gFonts['large'])
        love.graphics.printf("PAUSED", 0, VIRTUAL_HEIGHT / 2 - 16, VIRTUAL_WIDTH, 'center')
    end
end

function PlayState:checkVictory()
    for k, brick in pairs(self.bricks) do
        if brick.inPlay then
            return false
        end 
    end

    return true
end


-- function for ekstra balls

function PlayState:bonusBalls()

    if self.numBalls == 1 then
        ball2 = Ball(math.random(7))
        ball3 = Ball(math.random(7))

        ball2.x = VIRTUAL_WIDTH / 2 - 8
        ball2.y = VIRTUAL_HEIGHT / 2 - 8
        ball2.dx = self.balls[1].dx
        ball2.dy = self.balls[1].dy

        ball3.x = VIRTUAL_WIDTH / 2 - 8
        ball3.y = VIRTUAL_HEIGHT / 2 - 8
        ball3.dx = - self.balls[1].dx
        ball3.dy = - self.balls[1].dy

        table.insert(self.balls, ball2)
        table.insert(self.balls, ball3)
        self.numBalls = 3
    end

end