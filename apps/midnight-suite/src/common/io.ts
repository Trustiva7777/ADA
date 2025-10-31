import fs from "fs";
export function readText(path: string) { return fs.readFileSync(path, "utf8"); }
export function writeJSON(path: string, obj: any) {
  fs.mkdirSync(require("path").dirname(path), { recursive: true });
  fs.writeFileSync(path, JSON.stringify(obj, null, 2));
  console.log("Wrote", path);
}
export function parseCsv(text: string) {
  const [header, ...rows] = text.trim().split(/\r?\n/);
  const cols = header.split(",");
  return rows.map(r => {
    const cells = r.split(",");
    const obj: any = {};
    cols.forEach((c, i) => obj[c] = cells[i]);
    // coercions
    obj.usdAtSnapshot = Number(obj.usdAtSnapshot);
    obj.selfCustody = String(obj.selfCustody).toLowerCase() === "true";
    return obj;
  });
}
