"use client";

import { useEffect, useMemo, useRef, useState } from "react";
import styles from "./page.module.css";

type Profile = {
  name: string;
  allergies: string[];
  conditions: string[];
  preferences: string[];
  mobility: string;
  tts_enabled: boolean;
};

type HistoryItem = {
  summary: string;
  time: string;
};

const defaultProfile: Profile = {
  name: "Utilisateur",
  allergies: ["arachide"],
  conditions: ["diabete"],
  preferences: ["sans sucre"],
  mobility: "fauteuil",
  tts_enabled: true,
};

export default function Home() {
  const [apiBase, setApiBase] = useState(
    process.env.NEXT_PUBLIC_API_BASE ||
      "https://vision360-backend-276274707876.europe-west1.run.app/api",
  );
  const [profile, setProfile] = useState<Profile>(defaultProfile);
  const [imageB64, setImageB64] = useState("");
  const [prompt, setPrompt] = useState(
    "Decris precisement les produits/objets visibles, marques ou categories.",
  );
  const [voiceText, setVoiceText] = useState("");
  const [listening, setListening] = useState(false);
  const [voiceStatus, setVoiceStatus] = useState("");
  const [cameraOn, setCameraOn] = useState(false);
  const [captureStatus, setCaptureStatus] = useState("");
  const [geminiText, setGeminiText] = useState("");
  const [groqJson, setGroqJson] = useState("");
  const [geminiRaw, setGeminiRaw] = useState("");
  const [groqRaw, setGroqRaw] = useState("");
  const [loading, setLoading] = useState(false);
  const [history, setHistory] = useState<HistoryItem[]>([]);
  const [cooldownUntil, setCooldownUntil] = useState(0);
  const [cooldownMsg, setCooldownMsg] = useState("");

  const videoRef = useRef<HTMLVideoElement | null>(null);
  const canvasRef = useRef<HTMLCanvasElement | null>(null);

  const profileSummary = useMemo(
    () => ({
      ...profile,
      allergies: profile.allergies.filter(Boolean),
      conditions: profile.conditions.filter(Boolean),
      preferences: profile.preferences.filter(Boolean),
    }),
    [profile],
  );

  const updateList = (field: keyof Profile, value: string) => {
    setProfile((prev) => ({
      ...prev,
      [field]: value
        .split(",")
        .map((item) => item.trim())
        .filter(Boolean),
    }));
  };

  const callGemini = async () => {
    if (!apiBase) return;
    if (Date.now() < cooldownUntil) {
      setCooldownMsg("Attends 1 minute entre chaque envoi.");
      return;
    }
    setLoading(true);
    try {
      const res = await fetch(`${apiBase}/describe/gemini`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ image_b64: imageB64, prompt }),
      });
      if (!res.ok) {
        throw new Error(await res.text());
      }
      const data = await res.json();
      setGeminiText(data?.structured?.text ?? "");
      setCooldownUntil(Date.now() + 60_000);
      setCooldownMsg("");
    } catch (err) {
      setGeminiText(`Erreur Gemini: ${String(err)}`);
    } finally {
      setLoading(false);
    }
  };

  const callGroq = async () => {
    if (!apiBase) return;
    const description = voiceText.trim() || geminiText.trim();
    if (!description) return;
    if (Date.now() < cooldownUntil) {
      setCooldownMsg("Attends 1 minute entre chaque envoi.");
      return;
    }

    setLoading(true);
    try {
      const res = await fetch(`${apiBase}/describe/groq`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          description,
          profile_override: profileSummary,
        }),
      });
      if (!res.ok) {
        throw new Error(await res.text());
      }
      const data = await res.json();
      const structured = data?.structured ?? data;
      setGroqJson(JSON.stringify(structured, null, 2));
      setHistory((prev) => [
        {
          summary: structured?.summary ?? "Conseil",
          time: new Date().toLocaleString(),
        },
        ...prev,
      ]);
      setCooldownUntil(Date.now() + 60_000);
      setCooldownMsg("");
    } catch (err) {
      setGroqJson(`Erreur Groq: ${String(err)}`);
    } finally {
      setLoading(false);
    }
  };

  const startCamera = async () => {
    if (!navigator.mediaDevices?.getUserMedia) {
      setCaptureStatus("Camera non supportee sur ce navigateur.");
      return;
    }
    try {
      const stream = await navigator.mediaDevices.getUserMedia({
        video: { facingMode: "environment" },
        audio: false,
      });
      if (videoRef.current) {
        videoRef.current.srcObject = stream;
        await videoRef.current.play();
      }
      setCameraOn(true);
      setCaptureStatus("Camera activee.");
    } catch (err) {
      setCaptureStatus(`Erreur camera: ${String(err)}`);
    }
  };

  const stopCamera = () => {
    if (videoRef.current?.srcObject) {
      const tracks = (videoRef.current.srcObject as MediaStream).getTracks();
      tracks.forEach((track) => track.stop());
      videoRef.current.srcObject = null;
    }
    setCameraOn(false);
    setCaptureStatus("Camera arretee.");
  };

  const captureFrame = () => {
    const video = videoRef.current;
    const canvas = canvasRef.current;
    if (!video || !canvas) return;
    const width = video.videoWidth || 640;
    const height = video.videoHeight || 480;
    canvas.width = width;
    canvas.height = height;
    const ctx = canvas.getContext("2d");
    if (!ctx) return;
    ctx.drawImage(video, 0, 0, width, height);
    const dataUrl = canvas.toDataURL("image/jpeg", 0.8);
    setImageB64(dataUrl);
    return dataUrl;
  };

  const callChain = async (debug = false) => {
    if (!apiBase) return;
    if (Date.now() < cooldownUntil) {
      setCooldownMsg("Attends 1 minute entre chaque envoi.");
      return;
    }

    const captured = captureFrame();
    const imagePayload = captured || imageB64;
    if (!imagePayload) {
      setGeminiText("Aucune image a envoyer.");
      return;
    }

    setLoading(true);
    try {
      const geminiRes = await fetch(`${apiBase}/describe/gemini`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ image_b64: imagePayload, prompt }),
      });
      if (!geminiRes.ok) {
        throw new Error(await geminiRes.text());
      }
      const geminiData = await geminiRes.json();
      const geminiTextValue = geminiData?.structured?.text ?? "";
      setGeminiText(geminiTextValue);
      if (debug) {
        setGeminiRaw(JSON.stringify(geminiData, null, 2));
      }

      const groqRes = await fetch(`${apiBase}/describe/groq`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          description: geminiTextValue,
          profile_override: profileSummary,
        }),
      });
      if (!groqRes.ok) {
        throw new Error(await groqRes.text());
      }
      const groqData = await groqRes.json();
      const structured = groqData?.structured ?? groqData;
      setGroqJson(JSON.stringify(structured, null, 2));
      if (debug) {
        setGroqRaw(JSON.stringify(groqData, null, 2));
      }
      setHistory((prev) => [
        {
          summary: structured?.summary ?? "Conseil",
          time: new Date().toLocaleString(),
        },
        ...prev,
      ]);

      setCooldownUntil(Date.now() + 60_000);
      setCooldownMsg("");
    } catch (err) {
      setGroqJson(`Erreur chaine: ${String(err)}`);
      if (debug) {
        setGeminiRaw("");
        setGroqRaw("");
      }
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    return () => stopCamera();
  }, []);

  const startListening = () => {
    const SpeechRecognition =
      (window as any).SpeechRecognition || (window as any).webkitSpeechRecognition;
    if (!SpeechRecognition) {
      setVoiceStatus("Reconnaissance vocale non supportee sur ce navigateur.");
      return;
    }

    const recognition = new SpeechRecognition();
    recognition.lang = "fr-FR";
    recognition.interimResults = false;
    recognition.maxAlternatives = 1;

    recognition.onstart = () => {
      setListening(true);
      setVoiceStatus("Ecoute active...");
    };
    recognition.onresult = (event: any) => {
      const transcript = event.results[0][0].transcript;
      setVoiceText(transcript);
      setVoiceStatus(`Commande captee: ${transcript}`);
    };
    recognition.onerror = (event: any) => {
      setVoiceStatus(`Erreur micro: ${event.error || "inconnue"}`);
    };
    recognition.onend = () => {
      setListening(false);
    };

    recognition.start();
  };

  return (
    <div className={styles.page}>
      <header className={styles.header}>
        <div>
          <p className={styles.kicker}>Vision360</p>
          <h1>Console d&apos;assistance PMR</h1>
          <p className={styles.subtitle}>
            Profil sante, description Gemini et recommandations Groq en temps
            reel.
          </p>
        </div>
        <div className={styles.apiBox}>
          <label>Base API</label>
          <input
            value={apiBase}
            onChange={(event) => setApiBase(event.target.value)}
          />
        </div>
      </header>

      <section className={styles.grid}>
        <div className={styles.card}>
          <h2>Profil sante</h2>
          <div className={styles.field}>
            <label>Nom</label>
            <input
              value={profile.name}
              onChange={(event) =>
                setProfile((prev) => ({ ...prev, name: event.target.value }))
              }
            />
          </div>
          <div className={styles.field}>
            <label>Allergies</label>
            <input
              value={profile.allergies.join(", ")}
              onChange={(event) => updateList("allergies", event.target.value)}
            />
          </div>
          <div className={styles.field}>
            <label>Conditions</label>
            <input
              value={profile.conditions.join(", ")}
              onChange={(event) => updateList("conditions", event.target.value)}
            />
          </div>
          <div className={styles.field}>
            <label>Preferences</label>
            <input
              value={profile.preferences.join(", ")}
              onChange={(event) => updateList("preferences", event.target.value)}
            />
          </div>
          <div className={styles.field}>
            <label>Mobilite</label>
            <select
              value={profile.mobility}
              onChange={(event) =>
                setProfile((prev) => ({ ...prev, mobility: event.target.value }))
              }
            >
              <option value="fauteuil">Fauteuil</option>
              <option value="canne">Canne</option>
              <option value="marche">Marche</option>
            </select>
          </div>
          <label className={styles.switchRow}>
            <input
              type="checkbox"
              checked={profile.tts_enabled}
              onChange={(event) =>
                setProfile((prev) => ({
                  ...prev,
                  tts_enabled: event.target.checked,
                }))
              }
            />
            TTS actif (sortie Groq)
          </label>
        </div>

        <div className={styles.card}>
          <h2>Gemini</h2>
          <div className={styles.cameraBox}>
            <video ref={videoRef} className={styles.video} playsInline muted />
            <canvas ref={canvasRef} className={styles.canvas} />
          </div>
          <div className={styles.actions}>
            {!cameraOn ? (
              <button className={styles.secondary} onClick={startCamera}>
                Activer la camera
              </button>
            ) : (
              <button className={styles.secondary} onClick={stopCamera}>
                Arreter la camera
              </button>
            )}
            <button onClick={captureFrame}>Capturer</button>
            <button onClick={() => callChain(false)}>
              Envoyer (Recommandations)
            </button>
            <button onClick={() => callChain(true)}>
              Envoyer (Debug)
            </button>
          </div>
          {cooldownMsg && (
            <p className={styles.voiceStatus}>{cooldownMsg}</p>
          )}
          {captureStatus && <p className={styles.voiceStatus}>{captureStatus}</p>}
          <label>Image base64</label>
          <textarea
            rows={5}
            value={imageB64}
            onChange={(event) => setImageB64(event.target.value)}
          />
          <label>Prompt</label>
          <input
            value={prompt}
            onChange={(event) => setPrompt(event.target.value)}
          />
          <pre className={styles.output}>{geminiText || "—"}</pre>
          {geminiRaw && (
            <>
              <p className={styles.debugLabel}>Gemini raw</p>
              <pre className={styles.output}>{geminiRaw}</pre>
            </>
          )}
        </div>

        <div className={styles.card}>
          <h2>Groq</h2>
          <label>Commande vocale (texte)</label>
          <textarea
            rows={4}
            value={voiceText}
            onChange={(event) => setVoiceText(event.target.value)}
          />
          <div className={styles.actions}>
            <button
              className={styles.secondary}
              onClick={startListening}
              disabled={listening}
            >
              {listening ? "Ecoute en cours..." : "Activer l'ecoute"}
            </button>
            <button disabled={loading} onClick={callGroq}>
              Envoyer a Groq
            </button>
            <button
              className={styles.secondary}
              onClick={() => setVoiceText("")}
            >
              Reset
            </button>
          </div>
          {cooldownMsg && (
            <p className={styles.voiceStatus}>{cooldownMsg}</p>
          )}
          {voiceStatus && <p className={styles.voiceStatus}>{voiceStatus}</p>}
          <pre className={styles.output}>{groqJson || "—"}</pre>
          {groqRaw && (
            <>
              <p className={styles.debugLabel}>Groq raw</p>
              <pre className={styles.output}>{groqRaw}</pre>
            </>
          )}
        </div>
      </section>

      <section className={styles.card}>
        <h2>Historique</h2>
        {history.length === 0 ? (
          <p>Aucun conseil pour le moment.</p>
        ) : (
          <ul className={styles.history}>
            {history.map((item, index) => (
              <li key={`${item.time}-${index}`}>
                <span>{item.summary}</span>
                <small>{item.time}</small>
              </li>
            ))}
          </ul>
        )}
      </section>
    </div>
  );
}
