module myc3test;

import std::io;
import raylib6::rl;
import std::core::mem;

// --------------------
// Constants
// --------------------
const int SCREEN_WIDTH = 640;
const int SCREEN_HEIGHT = 360;

const int TILE_SIZE = 16;

const int ROOM_TILE_WIDTH = SCREEN_WIDTH / TILE_SIZE;
const int ROOM_TILE_HEIGHT = SCREEN_HEIGHT / TILE_SIZE;

const int WORLD_WIDTH = 2;
const int WORLD_HEIGHT = 3;

const int MAX_OBJECTS = 64;
const int MAX_EXITS = 16;
const int MAX_ENEMIES = 10;

// --------------------
// Types
// --------------------
enum Direction
{
    EAST,
    WEST,
    NORTH,
    SOUTH
}

enum GameObjectType
{
    SPAWN,
    ENEMYSPAWN,
    ITEM,
    EXIT
}

struct GameObject
{
    GameObjectType type;
    rl::RLVector2 position;
}

enum PatrolState
{
    GO_RIGHT,
    GO_START_FROM_RIGHT,
    GO_LEFT,
    GO_START_FROM_LEFT
}

struct WayPoint
{
    rl::RLVector2 start;
    rl::RLVector2 right;
    rl::RLVector2 left;
}

struct Player
{
    rl::RLVector2 position;
    Direction direction;
}

struct Enemy
{
    rl::RLVector2 position;
    Direction direction;
    WayPoint waypoint;
    PatrolState patrol_state;
}

struct RoomExit
{
    rl::RLRectangle area;
    int target_room;
    int target_x;
    int target_y;
}

struct Room
{
    uint[ROOM_TILE_WIDTH * ROOM_TILE_HEIGHT] ground;
    uint[ROOM_TILE_WIDTH * ROOM_TILE_HEIGHT] walls;
    GameObject[MAX_OBJECTS] objects;
    int object_count;
    Enemy[MAX_ENEMIES] enemies;
    int enemy_count;
    RoomExit[MAX_EXITS] exits;
    int exit_count;
}

struct World
{
    Room[WORLD_WIDTH * WORLD_HEIGHT] rooms;
}

struct Game
{
    Player player;
    World world;
    int current_room_idx;

    rl::RLTexture2D floor_texture;
    rl::RLTexture2D wall_texture;
    rl::RLTexture2D door_texture;
    rl::RLRenderTexture2D render_target;
    rl::RLRenderTexture2D light_mask;
    rl::RLTexture2D player_texture;
    rl::RLTexture2D enemy_texture;
}

// -------------------
// Room filenames
// --------------------
fn String get_room_filename(int room_id)
{
    switch(room_id)
    {
        case 0:
            return "resources/assets/maps/room1.tmj";
        case 1:
            return "resources/room2.json";
        case 2:
            return "resources/room3.json";
        default:
            return "resources/room1.json";
    }
}

// --------------------
// Player
// --------------------
fn void Player.set_position(&self, float x, float y)
{
    self.position.x = x;
    self.position.y = y;
}

// --------------------
// Enemy creation
// --------------------
fn void Room.add_enemy(&self, float x, float y)
{
    if (self.enemy_count >= MAX_ENEMIES)
    {
        return;
    }

    Enemy* enemy = &self.enemies[self.enemy_count];

    enemy.position.x = x;
    enemy.position.y = y;

    enemy.direction = EAST;

    enemy.waypoint.start = { x, y };

    enemy.waypoint.right = { x + 100, y };

    enemy.waypoint.left = { x - 100, y };

    enemy.patrol_state = GO_RIGHT;

    self.enemy_count++;
}

// --------------------
// Init
// --------------------
fn void Game.init_game(&self)
{
    self.current_room_idx = 0;

    self.player.position.x = 100;
    self.player.position.y = 100;

	// init world rooms - check for errors
    if(!self.world.rooms[0].load(self, get_room_filename(0)))
	{
		io::printn("Failed to load starting room");
	}
}

// --------------------
// Collision
// --------------------
fn bool Room.is_wall(&self, int x, int y)
{
    if (x < 0 || y < 0)
    {
        return true;
    }

    if (x >= ROOM_TILE_WIDTH || y >= ROOM_TILE_HEIGHT)
    {
        return true;
    }

    return self.walls[y * ROOM_TILE_WIDTH + x] != 0;
}

// --------------------
// Exits
// --------------------
fn void Game.check_room_exits(&self)
{
    Room* room = &self.world.rooms[self.current_room_idx];

    for(int i = 0; i < room.exit_count; i++)
    {
        RoomExit* exit = &room.exits[i];

        if(self.player.position.x >= exit.area.x &&
           self.player.position.x <= exit.area.x + exit.area.width &&
           self.player.position.y >= exit.area.y &&
           self.player.position.y <= exit.area.y + exit.area.height)
        {

            if(exit.target_room < 0 || exit.target_room >= WORLD_WIDTH * WORLD_HEIGHT)
            {
                return;
            }

            self.current_room_idx = exit.target_room;

            self.world.rooms[self.current_room_idx].load(self, get_room_filename(self.current_room_idx));

            self.player.position.x = exit.target_x;

            self.player.position.y = exit.target_y;

            return;
        }
    }
}

// -------------------
// Player update
// --------------------
fn void Game.update_player(&self, float delta_time)
{
    float speed = 60.0 * delta_time;

    rl::RLVector2 next = self.player.position;

    if (rl::is_key_down(rl::RLKeyboardKey.D))
    {
        next.x += speed;
        self.player.direction = EAST;
    }

    if (rl::is_key_down(rl::RLKeyboardKey.A))
    {
        next.x -= speed;
        self.player.direction = WEST;
    }

    if (rl::is_key_down(rl::RLKeyboardKey.W))
    {
        next.y -= speed;
        self.player.direction = NORTH;
    }

    if (rl::is_key_down(rl::RLKeyboardKey.S))
    {
        next.y += speed;
        self.player.direction = SOUTH;
    }

    if (self.can_move(next))
    {
        self.player.position = next;
    }
}

fn bool Game.can_move(&self, rl::RLVector2 position)
{
    Room* room = &self.world.rooms[self.current_room_idx];

    int left   = (int)position.x / TILE_SIZE;
    int right  = (int)(position.x + TILE_SIZE - 1) / TILE_SIZE;
    int top    = (int)position.y / TILE_SIZE;
    int bottom = (int)(position.y + TILE_SIZE - 1) / TILE_SIZE;

    if (room.is_wall(left, top) ||
        room.is_wall(right, top) ||
        room.is_wall(left, bottom) ||
        room.is_wall(right, bottom))
    {
        return false;
    }

    rl::RLRectangle player_rect = {
        position.x,
        position.y,
        TILE_SIZE,
        TILE_SIZE
    };

    foreach (enemy : room.enemies[..room.enemy_count])
    {
        rl::RLRectangle enemy_rect = {
            enemy.position.x,
            enemy.position.y,
            TILE_SIZE,
            TILE_SIZE
        };

        if (rl::check_collision_recs(player_rect, enemy_rect))
        {
            return false;
        }
    }

    return true;
}

// --------------------
// Enemy movement
// --------------------
fn bool Enemy.move_to(&self, Game* game, rl::RLVector2 target, float delta_time)
{
    float speed = 50.0 * delta_time;

    rl::RLVector2 next = self.position;

    if (next.x < target.x)
    {
        next.x += speed;
        if (next.x > target.x)
        {
            next.x = target.x;
        }
    }
    else if (next.x > target.x)
    {
        next.x -= speed;
        if (next.x < target.x)
        {
            next.x = target.x;
        }
    }

    if (next.y < target.y)
    {
        next.y += speed;
        if (next.y > target.y)
        {
            next.y = target.y;
        }
    }
    else if (next.y > target.y)
    {
        next.y -= speed;
        if (next.y < target.y)
        {
            next.y = target.y;
        }
    }

    rl::RLRectangle enemy_rect = {
        next.x,
        next.y,
        TILE_SIZE,
        TILE_SIZE
    };

    rl::RLRectangle player_rect = {
        game.player.position.x,
        game.player.position.y,
        TILE_SIZE,
        TILE_SIZE
    };

    if (!rl::check_collision_recs(enemy_rect, player_rect))
    {
        self.position = next;
    }

    return self.position.x == target.x &&
           self.position.y == target.y;
}

// --------------------
// Enemy AI
// --------------------
fn void Game.update_enemies(&self, float delta_time)
{
    Room* room = &self.world.rooms[self.current_room_idx];

    for (usz i = 0; i < (usz)room.enemy_count; i++)
    {
        Enemy* enemy = &room.enemies[i];

        switch (enemy.patrol_state)
        {
            case GO_RIGHT:
                if (enemy.move_to(self, enemy.waypoint.right, delta_time))
                {
                    enemy.patrol_state = GO_START_FROM_RIGHT;
                }
                break;

            case GO_START_FROM_RIGHT:
                if (enemy.move_to(self, enemy.waypoint.start, delta_time))
                {
                    enemy.patrol_state = GO_LEFT;
                }
                break;

            case GO_LEFT:
                if (enemy.move_to(self, enemy.waypoint.left, delta_time))
                {
                    enemy.patrol_state = GO_START_FROM_LEFT;
                }
                break;

            case GO_START_FROM_LEFT:
                if (enemy.move_to(self, enemy.waypoint.start, delta_time))
                {
                    enemy.patrol_state = GO_RIGHT;
                }
                break;
        }
    }
}

// --------------------
// Main update
// --------------------
fn void Game.update(&self, float delta_time)
{
    Room* room = &self.world.rooms[self.current_room_idx];

    self.update_player(delta_time);
    self.update_enemies(delta_time);    
    self.check_room_exits();
}

// --------------------
// Drawing
// --------------------
fn void Game.draw_room(&self, Room* room)
{
    for (usz i = 0; i < ROOM_TILE_WIDTH * ROOM_TILE_HEIGHT; i++)
    {
        int x = (int)(i % ROOM_TILE_WIDTH);
        int y = (int)(i / ROOM_TILE_WIDTH);

        uint gid = room.ground[i];

        if (gid != 0)
        {
            self.draw_tile(gid, x * TILE_SIZE, y * TILE_SIZE);
        }

        gid = room.walls[i];

        if (gid != 0)
        {
            self.draw_tile(gid, x * TILE_SIZE, y * TILE_SIZE);
        }
    }
}

fn void draw_room_exits(Room* room)
{
    foreach (exit : room.exits[..room.exit_count])
    {
        rl::draw_rectangle((int)exit.area.x, (int)exit.area.y, (int)exit.area.width, (int)exit.area.height, rl::WHITE );
    }
}


fn void draw_objects(Room* room)
{
    foreach (object : room.objects[..room.object_count])
    {
        rl::draw_rectangle((int)object.position.x, (int)object.position.y, TILE_SIZE,TILE_SIZE, rl::YELLOW);
    }
}


fn void Game.draw_player(&self)
{
    // rl::draw_rectangle((int)game.player.position.x, (int)game.player.position.y, TILE_SIZE, TILE_SIZE,rl::RED);

    rl::draw_texture(
        self.player_texture,
        (int)self.player.position.x,
        (int)self.player.position.y,
        rl::WHITE
    );
}


fn void Game.draw_enemies(&self, Room* room)
{
    foreach (enemy : room.enemies[..room.enemy_count])
    {
        // rl::draw_rectangle((int)enemy.position.x, (int)enemy.position.y, TILE_SIZE, TILE_SIZE, rl::ORANGE);
        rl::draw_texture(
            self.enemy_texture,
            (int)enemy.position.x,
            (int)enemy.position.y,
            rl::WHITE
        );
    }
}

fn void Game.draw_tile(&self, uint gid, int x, int y)
{
    rl::RLTexture2D texture;

    int first_gid;
    int columns;

    if(gid >= 242)
    {
        texture = self.door_texture;
        first_gid = 242;
        columns = 10;
    }
    else if(gid >= 50)
    {
        texture = self.wall_texture;
        first_gid = 50;
        columns = 24;
    }
    else
    {
        texture = self.floor_texture;
        first_gid = 1;
        columns = 7;
    }

    int local = (int)gid - first_gid;

    int sx = (local % columns) * TILE_SIZE;
    int sy = (local / columns) * TILE_SIZE;

    rl::draw_texture_rec(
        texture,
        (rl::RLRectangle)
        {
            sx,
            sy,
            TILE_SIZE,
            TILE_SIZE
        },
        (rl::RLVector2)
        {
            x,
            y
        },
        rl::WHITE
    );
}

fn void Game.draw_lighting(&self, float offset_x, float offset_y, float render_width, float render_height)
{
    rl::begin_texture_mode(self.light_mask);

    rl::clear_background(
        (rl::RLColor)
        {
            0,
            0,
            0,
            0
        }
    );

    rl::draw_rectangle(
        0,
        0,
        SCREEN_WIDTH,
        SCREEN_HEIGHT,
        (rl::RLColor)
        {
            0,
            0,
            0,
            235
        }
    );

    rl::begin_blend_mode(rl::RLBlendMode.SUBTRACT_COLORS);

    rl::draw_circle(
        (int)self.player.position.x + TILE_SIZE / 2,
        (int)self.player.position.y + TILE_SIZE / 2,
        120,
        rl::RAYWHITE
    );

    rl::end_blend_mode();

    rl::end_texture_mode();

    // Draw mask using same scaling as world
    rl::draw_texture_pro(
        self.light_mask.texture,
        (rl::RLRectangle)
        {
            0,
            0,
            SCREEN_WIDTH,
            -SCREEN_HEIGHT
        },

        (rl::RLRectangle)
        {
            offset_x,
            offset_y,
            render_width,
            render_height
        },

        (rl::RLVector2)
        {
            0,
            0
        },

        0,
        rl::WHITE
    );
}

fn void Game.draw(&self)
{
    Room* room = &self.world.rooms[self.current_room_idx];

    self.draw_room(room);
    self.draw_player();
    self.draw_enemies(room);
}

<*
Returns the quotient of two integers.
@param a: "Dividend"
@param b: "Divisor"
@require b != 0
@ensure return * b == a
*>
fn int divide(int a, int b)
{
    return a / b;
}
// -------------------
// Main
// --------------------
fn int main(String[] args)
{
	int result = divide(20, 5);
    io::printn(result); // Prints: 4

    Game game;

	// window things
    rl::set_config_flags(RLConfigFlag.WINDOW_RESIZABLE);

    rl::init_window(SCREEN_WIDTH, SCREEN_HEIGHT, "C3 Adventure");
    defer rl::close_window();

	// loading textures
    game.floor_texture = rl::load_texture("resources/assets/tilesets/Floor.png");
    game.wall_texture = rl::load_texture("resources/assets/tilesets/Walls.png");
    game.door_texture = rl::load_texture("resources/assets/tilesets/DoorsAndWalls.png");
    game.player_texture = rl::load_texture("resources/assets/entities/Player.png");
    game.enemy_texture = rl::load_texture("resources/assets/entities/Player.png");
    defer rl::unload_texture(game.floor_texture);
    defer rl::unload_texture(game.wall_texture);
    defer rl::unload_texture(game.door_texture);
    defer rl::unload_texture(game.player_texture);
    defer rl::unload_texture(game.enemy_texture);

	// load renders
    game.render_target = rl::load_render_texture(SCREEN_WIDTH, SCREEN_HEIGHT);
    defer rl::unload_render_texture(game.render_target);

    game.light_mask = rl::load_render_texture(SCREEN_WIDTH, SCREEN_HEIGHT);
    defer rl::unload_render_texture(game.light_mask);

    rl::set_target_fps(60);

	// init game instance
    Game.init_game(&game);

    while (!rl::window_should_close())
    {
		// get dt
        float delta_time = rl::get_frame_time();

        game.update(delta_time);

        // Draw world into render target
        rl::begin_texture_mode(game.render_target);

        rl::clear_background(rl::BLACK);

        game.draw();

        rl::end_texture_mode();


        rl::begin_drawing();

        rl::clear_background(rl::BLACK);

		// scaling window resizes game
        float scale_x = (float)rl::get_screen_width() / (float)SCREEN_WIDTH;
        float scale_y = (float)rl::get_screen_height() / (float)SCREEN_HEIGHT;

        float scale = scale_x < scale_y ? scale_x : scale_y;

        float render_width = SCREEN_WIDTH * scale;
        float render_height = SCREEN_HEIGHT * scale;

        float offset_x = ((float)rl::get_screen_width() - render_width) / 2.0f;
        float offset_y = ((float)rl::get_screen_height() - render_height) / 2.0f;


        // Draw game world
        rl::draw_texture_pro(
            game.render_target.texture,
            (rl::RLRectangle)
            {
                0,
                0,
                SCREEN_WIDTH,
                -SCREEN_HEIGHT
            },
            (rl::RLRectangle)
            {
                offset_x,
                offset_y,
                render_width,
                render_height
            },
            (rl::RLVector2)
            {
                0,
                0
            },
            0,
            rl::RAYWHITE
        );

        // Draw darkness/light mask ON TOP
        game.draw_lighting(
            offset_x,
            offset_y,
            render_width,
            render_height
        );

        rl::end_drawing();
    }

    return 0;
}