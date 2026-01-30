extends Node

func get_player_ref() -> Node3D:
    var players: Array[Node] = get_tree().get_nodes_in_group("Player")
    if players.size() == 0 or not players[0] is Node3D:
        print_debug("No players found")
        push_warning("No players found")
        return null
    return players[0] as Node3D