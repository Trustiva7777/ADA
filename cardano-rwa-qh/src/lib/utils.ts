import { createHash } from 'node:crypto';
import { parse } from 'fast-csv';
import fs from 'node:fs';

export function sha256Hex(buf: Buffer | string) {
  const h = createHash('sha256');
  h.update(buf);
  return h.digest('hex');
}

export async function readCsv(path: string): Promise<Record<string, string>[]> {
  return new Promise((resolve, reject) => {
    const rows: Record<string, string>[] = [];
    fs.createReadStream(path)
      .pipe(parse({ headers: true, ignoreEmpty: true, trim: true }))
      .on('error', reject)
      .on('data', row => rows.push(row))
      .on('end', () => resolve(rows));
  });
}

export function toAda(lovelace: bigint) {
  return Number(lovelace) / 1_000_000;
}
