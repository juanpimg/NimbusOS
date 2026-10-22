// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtTest
import Nimbus

// Contrato del envoltorio sobre Quickshell.Process (Task T3): invocar los
// CLI de Nimbus (nimbus-energy, nimbus-update, nimbus-gaming-tune) sin
// importar Quickshell estaticamente (este test corre sin compositor).
// `runner` inyectable ejecuta el comando; sin runner intenta el Process
// real de forma dinamica y falla con mensaje traducido, nunca lanza.
TestCase {
    id: root
    name: "Process"
    when: true

    // Doble de ejecutor: registra el comando y devuelve un resultado fijo.
    QtObject {
        id: fakeOk
        property var calls: []
        function run(cmd) {
            calls.push(cmd)
            return {"exitCode": 0, "stdout": "balanced\n", "stderr": ""}
        }
        function reset() { calls = [] }
    }

    QtObject {
        id: fakeFail
        function run(cmd) {
            return {"exitCode": 1, "stdout": "", "stderr": "boom"}
        }
    }

    Process { id: procOk; runner: fakeOk }
    Process { id: procFail; runner: fakeFail }
    Process { id: procAlone }

    SignalSpy { id: finishedSpy; target: procOk; signalName: "finished" }
    SignalSpy { id: failedSpy; target: procAlone; signalName: "failed" }

    function test_plain_command_is_forwarded_verbatim() {
        fakeOk.reset()
        procOk.command = "nimbus-energy"
        procOk.args = ["profile", "get"]
        procOk.privileged = false
        verify(procOk.start())
        compare(fakeOk.calls.length, 1)
        compare(fakeOk.calls[0].join(","), "nimbus-energy,profile,get")
    }

    function test_privileged_command_goes_through_polkit() {
        // Mismo patron que nimbus-energy: lo privilegiado se re-ejecuta con
        // pkexec (polkit); la lectura nunca pide privilegios.
        fakeOk.reset()
        procOk.command = "nimbus-energy"
        procOk.args = ["profile", "set", "balanced"]
        procOk.privileged = true
        verify(procOk.start())
        compare(fakeOk.calls.length, 1)
        compare(fakeOk.calls[0].join(","), "pkexec,nimbus-energy,profile,set,balanced")
    }

    function test_result_is_recorded_and_emitted() {
        procOk.command = "nimbus-energy"
        procOk.args = ["profile", "get"]
        procOk.privileged = false
        finishedSpy.clear()
        verify(procOk.start())
        compare(procOk.lastExitCode, 0)
        compare(procOk.lastStdout, "balanced\n")
        compare(procOk.lastStderr, "")
        compare(finishedSpy.count, 1)
    }

    function test_nonzero_exit_is_reported_not_thrown() {
        procFail.command = "nimbus-update"
        procFail.args = ["check"]
        verify(procFail.start())
        compare(procFail.lastExitCode, 1)
        compare(procFail.lastStderr, "boom")
    }

    function test_empty_command_fails_translated() {
        var probe = Qt.createQmlObject("import QtQuick; import Nimbus; Process {}", root)
        verify(probe !== null)
        probe.runner = fakeOk
        var failed = false
        probe.failed.connect(function (message) { failed = message !== "" })
        probe.command = ""
        verify(!probe.start())
        verify(failed)
        probe.destroy()
    }

    function test_long_output_is_truncated_for_display() {
        var big = ""
        for (var i = 0; i < 9000; ++i)
            big += "x"
        var local = Qt.createQmlObject("import QtQuick; import Nimbus; Process {}", root)
        local.recordResult(0, big, "")
        verify(local.lastStdout.length <= local.maxOutputChars)
        verify(local.displayStdout().length <= local.maxOutputChars)
        local.destroy()
    }

    function test_without_backend_fails_gracefully_translated() {
        // Sin Quickshell instalado (este entorno) el Process dinamico no
        // existe: debe emitir failed() con mensaje, sin lanzar ni colgarse.
        procAlone.command = "nimbus-energy"
        procAlone.args = ["profile", "get"]
        failedSpy.clear()
        verify(!procAlone.start())
        compare(failedSpy.count, 1)
        verify(procAlone.lastError !== "")
    }
}
