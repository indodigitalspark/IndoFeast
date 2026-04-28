export function initializeSse(res) {
  res.setHeader('Content-Type', 'text/event-stream');
  res.setHeader('Cache-Control', 'no-cache, no-transform');
  res.setHeader('Connection', 'keep-alive');
  res.flushHeaders?.();

  const heartbeat = setInterval(() => {
    res.write(': keep-alive\n\n');
  }, 15000);

  return () => {
    clearInterval(heartbeat);
    res.end();
  };
}

export function pushSse(res, payload) {
  res.write(`data: ${JSON.stringify(payload)}\n\n`);
}

export function watchChangeStreams(entries) {
  const cleanup = [];

  for (const entry of entries) {
    const stream = entry.model.watch([], { fullDocument: 'updateLookup' });
    const changeListener = (change) => entry.onChange(change);
    const errorListener = () => entry.onChange({ type: 'error' });

    stream.on('change', changeListener);
    stream.on('error', errorListener);

    cleanup.push(async () => {
      stream.off('change', changeListener);
      stream.off('error', errorListener);
      await stream.close().catch(() => {});
    });
  }

  return async () => {
    await Promise.all(cleanup.map((fn) => fn()));
  };
}
