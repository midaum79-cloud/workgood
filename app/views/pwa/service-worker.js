self.addEventListener("push", async (event) => {
  let data = { title: "일머리 알림", options: { body: "새로운 알림이 도착했습니다." } };
  
  try {
    if (event.data) {
      data = await event.data.json();
    }
  } catch (e) {
    console.error('Error parsing push data', e);
  }

  event.waitUntil(self.registration.showNotification(data.title, data.options));
});

self.addEventListener("notificationclick", function(event) {
  event.notification.close();
  
  const targetPath = event.notification.data?.path || "/";

  event.waitUntil(
    clients.matchAll({ type: "window" }).then((clientList) => {
      for (let i = 0; i < clientList.length; i++) {
        let client = clientList[i];
        let clientPath = (new URL(client.url)).pathname;

        if (clientPath === targetPath && "focus" in client) {
          return client.focus();
        }
      }

      if (clients.openWindow) {
        return clients.openWindow(targetPath);
      }
    })
  );
});
