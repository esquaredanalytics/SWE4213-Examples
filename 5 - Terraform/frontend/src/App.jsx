import React, { useEffect, useState } from "react";

const s = {
  page: { maxWidth: 800, margin: "0 auto", padding: "48px 24px" },
  card: { background: "#1e293b", borderRadius: 12, padding: 32, marginBottom: 24 },
  h1: { fontSize: 36, fontWeight: 700, color: "#f1f5f9" },
  h2: { fontSize: 22, fontWeight: 600, color: "#94a3b8", marginBottom: 16 },
  title: { color: "#38bdf8", marginBottom: 8, fontSize: 18 },
  muted: { color: "#64748b", fontSize: 14 },
  grid: { display: "grid", gridTemplateColumns: "repeat(auto-fill, minmax(180px, 1fr))", gap: 12 },
  skill: { background: "#0f172a", borderRadius: 8, padding: "10px 14px" },
  skillName: { fontWeight: 600, color: "#f1f5f9" },
  skillLevel: { color: "#64748b", fontSize: 13 },
  project: { marginBottom: 16 },
  projectName: { fontWeight: 600, fontSize: 17, color: "#f1f5f9" },
  projectDesc: { color: "#94a3b8", margin: "4px 0 6px" },
  link: { color: "#38bdf8", fontSize: 13, textDecoration: "none" },
  tag: { display: "inline-block", background: "#0f172a", borderRadius: 6, padding: "2px 10px", fontSize: 13, color: "#94a3b8", marginRight: 8 },
};

function useFetch(url) {
  const [data, setData] = useState(null);
  useEffect(() => {
    fetch(url).then((r) => r.json()).then(setData).catch(console.error);
  }, [url]);
  return data;
}

export default function App() {
  const profile = useFetch("/api/profile");
  const skills = useFetch("/api/skills");
  const projects = useFetch("/api/projects");

  if (!profile) return <div style={{ padding: 48, textAlign: "center", color: "#64748b" }}>Loading...</div>;

  return (
    <div style={s.page}>
      {/* Header */}
      <div style={s.card}>
        <h1 style={s.h1}>{profile.name}</h1>
        <p style={s.title}>{profile.title}</p>
        <p style={{ color: "#94a3b8", margin: "12px 0" }}>{profile.bio}</p>
        <span style={s.tag}>{profile.location}</span>
        <span style={s.tag}>{profile.email}</span>
        <a href={profile.github} style={s.link} target="_blank" rel="noreferrer">GitHub →</a>
      </div>

      {/* Skills */}
      {skills && (
        <div style={s.card}>
          <h2 style={s.h2}>Skills</h2>
          <div style={s.grid}>
            {skills.map((sk) => (
              <div key={sk.id} style={s.skill}>
                <div style={s.skillName}>{sk.name}</div>
                <div style={s.skillLevel}>{sk.level}</div>
              </div>
            ))}
          </div>
        </div>
      )}

      {/* Projects */}
      {projects && (
        <div style={s.card}>
          <h2 style={s.h2}>Projects</h2>
          {projects.map((p) => (
            <div key={p.id} style={s.project}>
              <div style={s.projectName}>{p.name}</div>
              <div style={s.projectDesc}>{p.description}</div>
              <a href={p.url} style={s.link} target="_blank" rel="noreferrer">View on GitHub →</a>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}