//// Numbers that only an Erlang runtime can give, computed per request.

import gleam/erlang/atom
import gleam/erlang/process.{type Pid}
import gleam/int
import gleam/list
import shared/stats.{type Stats, Stats}

pub fn current() -> Stats {
  Stats(
    otp_release: otp_release(),
    schedulers: system_info(atom.create("schedulers_online")),
    process_count: system_info(atom.create("process_count")),
    atom_count: system_info(atom.create("atom_count")),
    pid: pid_string(process.self()),
    worker_sum: sum_in_process([4, 8, 15, 16, 23, 42]),
  )
}

/// Spawns one process per number, each replying with its square and its pid.
pub fn squares(numbers: List(Int)) -> List(#(Int, Int, String)) {
  let reply_to = process.new_subject()
  list.each(numbers, fn(n) {
    process.spawn(fn() {
      process.send(reply_to, #(n, n * n, pid_string(process.self())))
    })
  })
  list.map(numbers, fn(_) {
    let assert Ok(reply) = process.receive(reply_to, within: 1000)
    reply
  })
  |> list.sort(fn(a, b) { int.compare(a.0, b.0) })
}

fn sum_in_process(numbers: List(Int)) -> Int {
  let reply_to = process.new_subject()
  process.spawn(fn() {
    process.send(reply_to, list.fold(numbers, 0, fn(acc, n) { acc + n }))
  })
  let assert Ok(total) = process.receive(reply_to, within: 1000)
  total
}

@external(erlang, "erlang", "system_info")
fn system_info(item: atom.Atom) -> Int

@external(erlang, "server_ffi", "otp_release")
fn otp_release() -> String

@external(erlang, "server_ffi", "pid_string")
pub fn pid_string(pid: Pid) -> String
