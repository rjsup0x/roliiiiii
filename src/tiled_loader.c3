module myc3test;

import std::io;
import std::io::file;
import std::encoding::json;
import std::collections::object;


// ------------------------------------------------
// Load room JSON
// ------------------------------------------------

fn void load_room(Game* game, Room* room, String filename)
{
    clear_room(room);

    char[] file_data =
        file::load_temp(filename)!!;


    String json_text =
        (String)file_data;


    Object* root =
        json::tparse(json_text)!!;


    Object* layers =
        root.get("layers")!!;



    for(sz i = 0; i < layers.get_len(); i++)
    {
        Object* layer =
            layers.get_at(i);


        String name =
            layer.get_string("name")!!;



        if(name == "Ground")
        {
            load_tile_layer(
                room.ground[..],
                layer
            );
        }
        else if(name == "Walls")
        {
            load_tile_layer(
                room.walls[..],
                layer
            );
        }
        else if(name == "Objects")
        {
            load_object_layer(
                game,
                room,
                layer
            );
        }
    }
}



// ------------------------------------------------
// Clear room
// ------------------------------------------------

fn void clear_room(Room* room)
{
    room.object_count = 0;
    room.enemy_count = 0;
    room.exit_count = 0;


    for(int i = 0;
        i < ROOM_TILE_WIDTH * ROOM_TILE_HEIGHT;
        i++)
    {
        room.ground[i] = 0;
        room.walls[i] = 0;
    }
}



// ------------------------------------------------
// Load tile layer
// ------------------------------------------------

fn void load_tile_layer(
    uint[] target,
    Object* layer)
{
    Object* data =
        layer.get("data")!!;


    for(sz i = 0; i < data.get_len(); i++)
    {
        target[i] =
            data.get_uint_at(i)!!;
    }
}



// ------------------------------------------------
// Read object property
// ------------------------------------------------

fn int get_property_int(
    Object* object,
    String property_name)
{
    if(!object.has_key("properties"))
    {
        return 0;
    }


    Object* properties =
        object.get("properties")!!;



    for(sz i = 0; i < properties.get_len(); i++)
    {
        Object* property =
            properties.get_at(i);



        String name =
            property.get_string("name")!!;



        if(name == property_name)
        {
            return property.get_int("value")!!;
        }
    }


    return 0;
}



// ------------------------------------------------
// Load object layer
// ------------------------------------------------

fn void load_object_layer(
    Game* game,
    Room* room,
    Object* layer)
{
    Object* objects =
        layer.get("objects")!!;



    for(sz i = 0; i < objects.get_len(); i++)
    {
        Object* source =
            objects.get_at(i);



        String type = "";

		if(source.has_key("properties"))
		{
			Object* properties =
				source.get("properties")!!;

			for(sz j = 0; j < properties.get_len(); j++)
			{
				Object* property =
					properties.get_at(j);

				String name =
					property.get_string("name")!!;

				if(name == "type")
				{
					type =
						property.get_string("value")!!;
					break;
				}
			}
		}



        float x =
            (float)source.get_float("x")!!;


        float y =
            (float)source.get_float("y")!!;



        // -------------------------
        // Player spawn
        // -------------------------

        if(type == "spawn")
        {
            set_player_position(
                game,
                x,
                y
            );

            continue;
        }



        // -------------------------
        // Enemy spawn
        // -------------------------

        if(type == "enemyspawn")
        {
            add_enemy(
                room,
                x,
                y
            );

            continue;
        }



        // -------------------------
        // Exit
        // -------------------------

        if(type == "exit")
        {
            if(room.exit_count >= MAX_EXITS)
            {
                continue;
            }

            RoomExit* exit =
                &room.exits[room.exit_count];

			float width = (float)source.get_float("width")!!;

			float height =
				(float)source.get_float("height")!!;

			if(width == 0)
			{
				width = TILE_SIZE;
			}

			if(height == 0)
			{
				height = TILE_SIZE;
			}

			exit.area.x = x;
			exit.area.y = y;
			exit.area.width = width;
			exit.area.height = height;

            exit.target_room =
                get_property_int(
                    source,
                    "target_room"
                );


            exit.target_x =
                get_property_int(
                    source,
                    "target_x"
                );


            exit.target_y =
                get_property_int(
                    source,
                    "target_y"
                );


            room.exit_count++;


            continue;
        }



        // -------------------------
        // Normal object
        // -------------------------

        if(room.object_count >= MAX_OBJECTS)
        {
            continue;
        }



        GameObject* obj =
            &room.objects[room.object_count];



        obj.type =
            parse_object_type(type);


        obj.position.x = x;

        obj.position.y = y;


        room.object_count++;
    }
}



// ------------------------------------------------
// Object type parser
// ------------------------------------------------

fn GameObjectType parse_object_type(
    String type)
{
    if(type == "item")
    {
        return ITEM;
    }


    if(type == "enemyspawn")
    {
        return ENEMYSPAWN;
    }


    if(type == "exit")
    {
        return EXIT;
    }


    if(type == "spawn")
    {
        return SPAWN;
    }


    return ITEM;
}