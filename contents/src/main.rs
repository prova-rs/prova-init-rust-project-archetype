use {{ ident }}::greeting;

// No .unwrap()/.expect() here, deliberately: production code is under the census in
// proofs/quality/unwrap.prova.lua, and the scaffold starts the ratchet at zero.
fn main() {
    let name = std::env::args().nth(1).unwrap_or_else(|| "world".to_string());
    println!("{}", greeting(&name));
}
