import Sidebar from '../components/SideBar/SideBar';
import TopMenuBar from '../components/TopMenuBar/TopMenuBar';
import Showcase from '../components/Showcase/Showcase';

export function SamplePage() {
    return (
        <div data-testid="sample-page-root"
            style={{ 
                display: 'flex', 
                flexDirection: 'column', 
                height: '100vh', 
                width: '100%', 
                overflowX: 'hidden', 
                backgroundColor: '#f4f6f8', 
                boxSizing: 'border-box' 
            }}
        >
            <div style={{ flexShrink: 0, width: '100%' }}>
                <TopMenuBar />
            </div>
            <div style={{ display: 'flex', flexGrow: 1, overflow: 'hidden', width: '100%' }}>
                <Sidebar />
                <div data-testid="main-content"
                    style={{
                        flexGrow: 1,
                        display: 'flex',
                        alignContent: 'center', 
                        alignItems: 'center', 
                        flexDirection: 'column', 
                        overflowY: 'auto',
                        overflowX: 'hidden', 
                        backgroundColor: '#ffffff',
                        borderTopLeftRadius: '12px',
                        boxShadow: '0px 4px 8px rgba(0, 0, 0, 0.1)',
                        padding: '20px',
                        margin: '0',
                        width: '100%',
                        boxSizing: 'border-box'
                    }}
                >
                    <main style={{ padding: '20px', flexGrow: 1, width: '100%' }}>
                        <h1 data-testid="page-heading">Welcome to Sample Page</h1>  {/* ✅ Add a heading for testability */}
                        <Showcase />
                    </main>
                </div>
            </div>
        </div>
    );
}
