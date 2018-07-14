// NOTE: The contents of this file will only be executed if
// you uncomment its entry in "assets/js/app.js".

// To use Phoenix channels, the first step is to import Socket
// and connect at the socket path in "lib/web/endpoint.ex":
import {Socket} from "phoenix"

// let socket = new Socket("/socket", {params: {token: window.userToken}})
let socket = new Socket("/socket", {params: {token: "SFMyNTY.g3QAAAACZAAEZGF0YXQAAAACZAAFdG9rZW5tAAAArC1KV1E1NTZoME5SNDBETklBdUl4eTRkekRCa014aGk4a2Zta2xPYTdhVVk2UkVLMDN5ZmI5S1p2UVdob0thMFA4dlB1NDlraVFsOVpFLU4ySHU5WUU0NjMwX2NreWZ6bE01eUFHMVgxbXdnVzU2aVJyOU9JNVp5WnF0WXc1NVVpdGNEeFkwV2d0ZVhYZjZFVUp6RVNtcVdEbFFzdV9wV3dmYnZlenNHN3NoMD1kAAd1c2VyX2lkYQFkAAZzaWduZWRuBgCYp6bWXwE.sWGneHnW_X9isltCJRD3g47PaQuAgu-TN8ylU8pIRA0"}});

// When you connect, you'll often need to authenticate the client.
// For example, imagine you have an authentication plug, `MyAuth`,
// which authenticates the session and assigns a `:current_user`.
// If the current user exists you can assign the user's token in
// the connection for use in the layout.
//
// In your "lib/web/router.ex":
//
//     pipeline :browser do
//       ...
//       plug MyAuth
//       plug :put_user_token
//     end
//
//     defp put_user_token(conn, _) do
//       if current_user = conn.assigns[:current_user] do
//         token = Phoenix.Token.sign(conn, "user socket", current_user.id)
//         assign(conn, :user_token, token)
//       else
//         conn
//       end
//     end
//
// Now you need to pass this token to JavaScript. You can do so
// inside a script tag in "lib/web/templates/layout/app.html.eex":
//
//     <script>window.userToken = "<%= assigns[:user_token] %>";</script>
//
// You will need to verify the user token in the "connect/2" function
// in "lib/web/channels/user_socket.ex":
//
//     def connect(%{"token" => token}, socket) do
//       # max_age: 1209600 is equivalent to two weeks in seconds
//       case Phoenix.Token.verify(socket, "user socket", token, max_age: 1209600) do
//         {:ok, user_id} ->
//           {:ok, assign(socket, :user, user_id)}
//         {:error, reason} ->
//           :error
//       end
//     end
//
// Finally, pass the token on connect as below. Or remove it
// from connect if you don't care about authentication.

socket.connect()

// Now that you are connected, you can join channels with a topic:
let channel = socket.channel("conversation:lobby", {});
let channel1 = socket.channel("conversation:28", {});
channel1.onClose(() => console.log("Closed!!!!"));
let notify = socket.channel("notify:1", {});
channel.join()
    .receive("ok", resp => {
        console.log("Joined successfully", resp);
    })
    .receive("error", resp => { console.log("Unable to join", resp) });
channel1.join()
    .receive("ok", resp => {
        console.log("Joined successfully", resp);
    })
    .receive("error", resp => { console.log("Unable to join", resp) });
notify.join()
    .receive("ok", resp => {
        console.log("Joined successfully", resp);
    })
    .receive("error", resp => { console.log("Unable to join", resp) });

channel.on("new_msg", msg => console.log("Got msg", msg));

notify.on("removed", msg => {
    setTimeout(function () {
        channel1.leave(100);
    }, 3000);
    // channel1.leave(100);
    console.log("Got msg", msg);}
    );

let input = document.getElementById("aaa");

input.addEventListener("keyup", e => {
    if (e.keyCode === 13) {

        channel.push("create", {users: [1], title: "aaa"})
            .receive("ok", (msg) => console.log("created message", msg))
            .receive("error", (reasons) => console.log("11create failed", reasons))
            .receive("timeout", () => console.log("Networking issue..."));

        channel1.push("remove", {user_id: 1})
            .receive("ok", (msg) => console.log("created message", msg))
            .receive("error", (reasons) => console.log("11create failed", reasons))
            .receive("timeout", () => console.log("Networking issue..."));

        // channel.push("msg", {content: input.value, type: "a"}, 1000)
        //     .receive("ok", (msg) => console.log("created message", msg))
        //     .receive("error", (reasons) => console.log("create failed", reasons))
        //     .receive("timeout", () => console.log("Networking issue..."))
    }
});


export default socket
