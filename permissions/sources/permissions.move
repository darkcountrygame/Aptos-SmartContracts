module dev::permissions
{

public fun check_permission(addr: address): bool {
    
    let is_host = (addr == @host);
    let is_dev = (addr == @dev);
    let is_server = (addr == @server);

    (is_host || is_dev || is_server)
}

public fun check_mint_permissions(addr: address): bool {
    let is_host = (addr == @host);
    let is_dev = (addr == @dev);
    let is_server = (addr == @server);
    let is_unpacker = (addr == @unpacker);
    let is_drops = (addr == @drops);

    (is_host || is_dev || is_server || is_unpacker || is_drops)
}

public fun is_host(addr: address): bool {
    (addr == @host)
}

}