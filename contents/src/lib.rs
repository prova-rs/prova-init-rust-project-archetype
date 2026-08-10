//! Starter library — replace with your project's real modules. It exists so every quality leg has
//! something true to hold on day one: a unit test for the ut/coverage legs, production code for the
//! clippy wall and the unwrap/expect census.

/// Compose a greeting for `name`.
pub fn greeting(name: &str) -> String {
    format!("hello, {name}")
}

#[cfg(test)]
mod tests {
    use super::greeting;

    // `prova run ut` conducts these via cargo nextest and adopts every case into the account;
    // proofs/ut/nextest.prova.lua binds this one by name (`tests::greets_by_name`) as the example
    // of a claim discharged by a specific unit test.
    #[test]
    fn greets_by_name() {
        assert_eq!(greeting("prova"), "hello, prova");
    }
}
