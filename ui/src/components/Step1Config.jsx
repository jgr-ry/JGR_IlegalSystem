import React, { useState } from 'react';

export default function Step1Config({ config, onComplete, onClose }) {
    const [name, setName] = useState('');
    const [color, setColor] = useState('#ff0000');

    return (
        <div style={{ width: '80%', background: 'rgba(0,0,0,0.5)', padding: '20px', borderRadius: '10px' }}>
            <h1>CREAR TU ORGANIZACIÓN</h1>
            <p>Configura los aspectos esenciales.</p>

            <div style={{ display: 'flex', gap: '20px', marginBottom: '20px' }}>
                <input type="color" value={color} onChange={(e) => setColor(e.target.value)} style={{ width: '50px', height: '50px' }} />
                <input
                    type="text"
                    placeholder="NOMBRE DE LA ORGANIZACIÓN"
                    value={name}
                    onChange={(e) => setName(e.target.value)}
                    style={{ flex: 1, padding: '10px', fontSize: '18px', background: 'rgba(255,255,255,0.8)' }}
                />
            </div>

            <div style={{ display: 'flex', gap: '20px' }}>
                <div style={{ width: '30%', background: 'rgba(0,0,0,0.7)', padding: '10px' }}>
                    <h3>RANKS MOCKUP</h3>
                    <ul><li>Jefe</li><li>Nuevo Rango</li></ul>
                </div>
                <div style={{ width: '70%', background: 'rgba(0,0,0,0.7)', padding: '10px' }}>
                    <h3>PERMISSIONS MOCKUP</h3>
                    {config?.BasePermissions && Object.entries(config.BasePermissions).map(([key, label]) => (
                        <div key={key} style={{ display: 'flex', justifyContent: 'space-between', marginBottom: '10px' }}>
                            <span>{label}</span>
                            <input type="checkbox" />
                        </div>
                    ))}
                </div>
            </div>

            <div style={{ marginTop: '20px', display: 'flex', justifyContent: 'flex-end', gap: '10px' }}>
                <button onClick={onClose} style={{ padding: '10px 20px', background: 'red', color: 'white', border: 'none', cursor: 'pointer' }}>CANCELAR</button>
                <button
                    onClick={() => onComplete({ name, color, ranks: ['Jefe'] })}
                    style={{ padding: '10px 20px', background: 'white', color: 'black', border: 'none', fontWeight: 'bold', cursor: 'pointer' }}>
                    CONTINUAR
                </button>
            </div>
        </div>
    );
}
