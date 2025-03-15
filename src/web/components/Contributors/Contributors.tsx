import { Card, Button, Text, Avatar } from "@fluentui/react-components";
import "./Contributors.css";

function ContributorsSection() {
    const contributors = [
        { name: "Michael Flanakin", avatar: "https://avatars.githubusercontent.com/u/399533?v=4?s=100", roles: ["🌟", "💻", "👀", "📖", "🧑‍🏫", "📣"], profileLink: "http://about.me/flanakin" },
        { name: "Arthur Clares", avatar: "https://avatars.githubusercontent.com/u/53261392?v=4?s=100", roles: ["🌟", "💻", "👀", "📖", "🧑‍🏫", "📣"], profileLink: "https://github.com/arthurclares" },
        { name: "Sonia Cuff", avatar: "https://avatars.githubusercontent.com/u/41356020?v=4?s=100", roles: ["🌟", "📣"], profileLink: "https://github.com/scuffy" },
        { name: "maggar", avatar: "https://avatars.githubusercontent.com/u/55561955?v=4?s=100", roles: ["🌟", "🤔"], profileLink: "https://github.com/maggar" },
        { name: "Brett Wilson", avatar: "https://avatars.githubusercontent.com/u/24294904?v=4?s=100", roles: ["💻", "👀", "📖"], profileLink: "https://github.com/MSBrett" },
        { name: "Seif Bassem", avatar: "https://avatars.githubusercontent.com/u/38246040?v=4?s=100", roles: ["💻"], profileLink: "https://www.seifbassem.com/" },
        { name: "Anthony Romano", avatar: "https://avatars.githubusercontent.com/u/26576969?v=4?s=100", roles: ["💻", "👀", "📖"], profileLink: "https://github.com/aromano2" },
        { name: "Nicolas Teyan", avatar: "https://avatars.githubusercontent.com/u/8894656?v=4?s=100", roles: ["💻", "📖"], profileLink: "https://github.com/nteyan" },
        { name: "Sacha Narinx", avatar: "https://avatars.githubusercontent.com/u/2101287?v=4?s=100", roles: ["💻", "👀", "📖"], profileLink: "https://github.com/Springstone" },
        { name: "Jamel Achahbar", avatar: "https://avatars.githubusercontent.com/u/127963872?v=4?s=100", roles: ["💻"], profileLink: "https://github.com/jamelachahbar" },
        { name: "Saad Mahmood", avatar: "https://avatars.githubusercontent.com/u/66096650?v=4?s=100", roles: ["💻"], profileLink: "https://github.com/saadmsft" },
        { name: "Divyadeep Dayal", avatar: "https://avatars.githubusercontent.com/u/81250915?v=4?s=100", roles: ["💻"], profileLink: "https://github.com/didayal-msft" },
        { name: "Arjen Huitema", avatar: "https://avatars.githubusercontent.com/u/15944031?v=4?s=100", roles: ["💻"], profileLink: "https://github.com/arjenhuitema" },
        { name: "Bill Anderson", avatar: "https://avatars.githubusercontent.com/u/9596428?v=4?s=100", roles: ["📖"], profileLink: "https://github.com/bandersmsft" },
        { name: "Hélder Pinto", avatar: "https://avatars.githubusercontent.com/u/10661605?v=4?s=100", roles: ["💻", "👀", "📖", "🐛"], profileLink: "https://aka.ms/helderpinto" },
        { name: "Yuan Zhang", avatar: "https://avatars.githubusercontent.com/u/114724932?v=4?s=100", roles: ["💻"], profileLink: "https://aka.ms/yuanzhang9" },
        { name: "ymehdimsft", avatar: "https://avatars.githubusercontent.com/u/134303029?v=4?s=100", roles: ["💻"], profileLink: "https://github.com/ymehdimsft" },
        { name: "srilatha inavolu", avatar: "https://avatars.githubusercontent.com/u/4493254?v=4?s=100", roles: ["💻", "👀"], profileLink: "https://github.com/sri-" },
        { name: "soumyananda", avatar: "https://avatars.githubusercontent.com/u/7952916?v=4?s=100", roles: ["💻", "👀"], profileLink: "https://github.com/soumyananda" },
        { name: "Chris Bowman", avatar: "https://avatars.githubusercontent.com/u/20289947?v=4?s=100", roles: ["🐛"], profileLink: "https://github.com/chris-bowman" },
        { name: "Mubarak Tanseer", avatar: "https://avatars.githubusercontent.com/u/64589176?v=4?s=100", roles: ["🐛"], profileLink: "https://github.com/mutansee" },
        { name: "Ben Shy", avatar: "https://avatars.githubusercontent.com/u/18198475?v=4?s=100", roles: ["💻", "👀"], profileLink: "https://github.com/BenShy" },
        { name: "Trey Morgan", avatar: "https://avatars.githubusercontent.com/u/18508457?v=4?s=100", roles: ["💻"], profileLink: "https://github.com/treymorgan" },
    ];

    return (
        <>
            <div className="ftk-contributors-title">
                <Text size={600} weight="semibold">Contributors</Text>
            </div>

            <div className="ftk-background-card">
                <div className="ftk-left-section">
                    <Text size={500} weight="regular">Get help from the community or contribute to the project</Text>
                    <Text size={300}>
                        Reporting is critical for any FinOps initiative. FinOps toolkit datasets help you clean and normalize data as part of data ingestion and reporting efforts.
                    </Text>
                    <div className="ftk-card-actions">
                        <Button appearance="secondary" size="large">Get help</Button>
                        <Button appearance="secondary" size="large">Share ideas</Button>
                        <Button appearance="secondary" size="large">Get involved</Button>
                    </div>
                </div>

                <div className="ftk-contributors-grid">
                    {contributors.map((contributor, index) => (
                        <a href={contributor.profileLink} key={index} target="_blank" rel="noopener noreferrer">
                            <Card className="ftk-contributors-card">
                                <Avatar image={{ src: contributor.avatar }} name={contributor.name} size={64} />
                                <Text size={300} weight="semibold" className="ftk-contributor-name">{contributor.name}</Text>
                                <div>{contributor.roles.map((role, i) => <span key={i}>{role}</span>)}</div>
                            </Card>
                        </a>
                    ))}
                </div>
            </div>
        </>
    );
}

export default ContributorsSection;
